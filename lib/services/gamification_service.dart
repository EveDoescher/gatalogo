import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/gamification.dart';
import '../stores/session_store.dart';
import 'product_api_service.dart';

class GamificationService {
  GamificationService(this._sessionStore, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final SessionStore _sessionStore;
  final FlutterSecureStorage _storage;
  static const _storageKey = 'local_gamification_cache';

  GamificationState? _cachedState;
  GamificationState get currentState => _cachedState ?? GamificationState.initial();

  Future<GamificationState> loadGamification() async {
    // 1. Try local cache first for instant UI response
    if (_cachedState == null) {
      try {
        final raw = await _storage.read(key: _storageKey);
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          _cachedState = GamificationState.fromMap(decoded);
        }
      } catch (e) {
        debugPrint('Erro ao ler cache de gamificação: $e');
      }
    }

    // 2. Fetch fresh state from remote API if signed in
    if (_sessionStore.isSignedIn) {
      try {
        final api = ProductApiService(_sessionStore);
        final data = await api.get('/app/gamification');
        final newState = GamificationState.fromMap(data);
        _cachedState = newState;
        await _persistLocally(newState);
        return newState;
      } catch (e) {
        debugPrint('Erro ao carregar gamificação remota: $e');
      }
    }

    return _cachedState ?? GamificationState.initial();
  }

  Future<GamificationActionResult> recordAction(
    String action, {
    String? contextId,
  }) async {
    if (_sessionStore.isSignedIn) {
      try {
        final api = ProductApiService(_sessionStore);
        final response = await api.post(
          '/app/gamification/action',
          {
            'action': action,
            'context_id': contextId,
          },
        );

        GamificationState updatedState;
        if (response.containsKey('daily_missions') ||
            response.containsKey('xp') ||
            response.containsKey('new_xp')) {
          final merged = {
            ..._cachedState?.toMap() ?? {},
            ...response,
            'xp': (response['xp'] as num?)?.toInt() ??
                (response['new_xp'] as num?)?.toInt() ??
                _cachedState?.xp ??
                0,
          };
          updatedState = GamificationState.fromMap(merged);
          _cachedState = updatedState;
          await _persistLocally(updatedState);
        } else {
          updatedState = await loadGamification();
        }

        final missions = (response['missions_completed'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        return GamificationActionResult(
          state: updatedState,
          earnedXp: (response['earned_xp'] as num?)?.toInt() ?? 10,
          multiplier: (response['multiplier'] as num?)?.toDouble() ?? 1.0,
          levelUp: response['level_up'] == true,
          level: (response['level'] as num?)?.toInt() ?? updatedState.level,
          levelTitle: response['level_title']?.toString() ?? updatedState.levelTitle,
          missionsCompleted: missions,
        );
      } catch (e) {
        debugPrint('Erro ao registrar ação de gamificação remota: $e');
      }
    }

    // Local offline simulation fallback
    final current = currentState;
    final earned = (action == 'photo'
        ? 50
        : action == 'sighting'
            ? 40
            : action == 'post'
                ? 30
                : action == 'comment'
                    ? 15
                    : action == 'share'
                        ? 25
                        : action == 'care'
                            ? 25
                            : 10);
    var bonusFromMissions = 0;
    final completedMissions = <String>[];
    final updatedDaily = current.dailyMissions.map((m) {
      var advances = false;
      if (m.id == 'daily_photo' && (action == 'photo')) advances = true;
      if (m.id == 'daily_social' && (action == 'like' || action == 'comment' || action == 'post')) advances = true;
      if (m.id == 'daily_care' && (action == 'sighting' || action == 'photo' || action == 'share' || action == 'care')) advances = true;
      if (advances && !m.completed) {
        final newProg = (m.progress + 1).clamp(0, m.target);
        final isDone = newProg >= m.target;
        if (isDone) {
          bonusFromMissions += m.xpReward;
          completedMissions.add(m.title);
        }
        return m.copyWith(progress: newProg, completed: isDone);
      }
      return m;
    }).toList();

    var updatedBonus = current.bonusMission;
    if (action == 'share' && updatedBonus != null && !updatedBonus.completed) {
      final newProg = (updatedBonus.progress + 1).clamp(0, updatedBonus.target);
      final isDone = newProg >= updatedBonus.target;
      if (isDone) {
        bonusFromMissions += updatedBonus.xpReward;
        completedMissions.add(updatedBonus.title);
      }
      updatedBonus = updatedBonus.copyWith(progress: newProg, completed: isDone);
    }

    final newXp = current.xp + earned + bonusFromMissions;
    final offlineState = GamificationState(
      xp: newXp,
      level: current.level,
      levelTitle: current.levelTitle,
      levelMinXp: current.levelMinXp,
      targetXp: current.targetXp,
      levelReward: current.levelReward,
      streak: current.streak > 0 ? current.streak : 1,
      longestStreak: current.longestStreak > 0 ? current.longestStreak : 1,
      multiplier: current.multiplier,
      freezeShields: current.freezeShields,
      dailyMissions: updatedDaily,
      weeklyMission: current.weeklyMission,
      bonusMission: updatedBonus,
      unlockedAchievements: current.unlockedAchievements,
      totalAchievements: current.totalAchievements,
    );

    _cachedState = offlineState;
    await _persistLocally(offlineState);

    return GamificationActionResult(
      state: offlineState,
      earnedXp: earned + bonusFromMissions,
      multiplier: current.multiplier,
      levelUp: false,
      level: offlineState.level,
      levelTitle: offlineState.levelTitle,
      missionsCompleted: completedMissions,
    );
  }

  Future<void> _persistLocally(GamificationState state) async {
    try {
      final jsonStr = jsonEncode(state.toMap());
      await _storage.write(key: _storageKey, value: jsonStr);
    } catch (e) {
      debugPrint('Erro ao persistir gamificação: $e');
    }
  }
}
