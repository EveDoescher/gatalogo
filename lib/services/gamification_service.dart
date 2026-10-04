import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/gamification.dart';
import '../stores/session_store.dart';
import 'product_api_service.dart';

/// Ordered server-confirmed progress, isolated by account.
class GamificationService {
  GamificationService(
    this._sessionStore, {
    FlutterSecureStorage? storage,
    ProductApiService? api,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _api = api ?? ProductApiService(_sessionStore);

  final SessionStore _sessionStore;
  final FlutterSecureStorage _storage;
  final ProductApiService _api;
  GamificationState? _cachedState;
  Future<void> _pending = Future.value();
  int _generation = 0;

  GamificationState get currentState =>
      _cachedState ?? GamificationState.initial();

  void reset() {
    _generation++;
    _cachedState = null;
    _pending = Future.value();
  }

  Future<T> _ordered<T>(Future<T> Function(bool Function(), String) operation) {
    final generation = _generation;
    final owner = _sessionStore.session?.userId;
    bool isCurrent() =>
        generation == _generation && owner == _sessionStore.session?.userId;
    final result = _pending.then(
      (_) =>
          operation(isCurrent, 'local_gamification_cache_${owner ?? 'guest'}'),
    );
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<GamificationState> loadGamification() =>
      _ordered((isCurrent, key) async {
        if (!isCurrent()) return currentState;
        if (_cachedState == null) {
          try {
            final raw = await _storage.read(key: key);
            if (!isCurrent()) return currentState;
            if (raw != null) {
              _cachedState = GamificationState.fromMap(
                jsonDecode(raw) as Map<String, dynamic>,
              );
            }
          } catch (e) {
            debugPrint('Erro ao ler cache de gamificação: $e');
          }
        }
        if (!isCurrent() || !_sessionStore.isSignedIn) return currentState;
        try {
          final data = await _api.get('/app/gamification');
          if (!isCurrent()) return currentState;
          _cachedState = GamificationState.fromMap(data);
          await _persistLocally(currentState, key);
        } catch (e) {
          debugPrint('Erro ao carregar gamificação remota: $e');
        }
        return currentState;
      });

  Future<GamificationActionResult> recordAction(
    String action, {
    String? contextId,
  }) => _ordered((isCurrent, key) async {
    if (!isCurrent() || !_sessionStore.isSignedIn) return _unchanged();
    try {
      final response = await _api.post('/app/gamification/action', {
        'action': action,
        'context_id': contextId,
      });
      if (!isCurrent()) return _unchanged();
      if (response.containsKey('xp') || response.containsKey('new_xp')) {
        _cachedState = GamificationState.fromMap({
          ...currentState.toMap(),
          ...response,
          'xp': response['xp'] ?? response['new_xp'],
        });
      } else {
        final data = await _api.get('/app/gamification');
        if (!isCurrent()) return _unchanged();
        _cachedState = GamificationState.fromMap(data);
      }
      await _persistLocally(currentState, key);
      if (!isCurrent()) return _unchanged();
      return GamificationActionResult(
        state: currentState,
        earnedXp: (response['earned_xp'] as num?)?.toInt() ?? 0,
        multiplier: (response['multiplier'] as num?)?.toDouble() ?? 1,
        levelUp: response['level_up'] == true,
        level: currentState.level,
        levelTitle: currentState.levelTitle,
        missionsCompleted:
            (response['missions_completed'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            [],
      );
    } catch (e) {
      // Failed requests cannot award XP or invent progress locally.
      debugPrint('Erro ao registrar ação de gamificação remota: $e');
      return _unchanged();
    }
  });

  GamificationActionResult _unchanged() => GamificationActionResult(
    state: currentState,
    earnedXp: 0,
    multiplier: currentState.multiplier,
    levelUp: false,
    level: currentState.level,
    levelTitle: currentState.levelTitle,
    missionsCompleted: const [],
  );

  Future<void> _persistLocally(GamificationState state, String key) async {
    try {
      await _storage.write(key: key, value: jsonEncode(state.toMap()));
    } catch (e) {
      debugPrint('Erro ao persistir gamificação: $e');
    }
  }
}
