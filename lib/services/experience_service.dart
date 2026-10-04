import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device preferences: silence is always stronger than an in-app setting.
class ExperienceService extends ChangeNotifier with WidgetsBindingObserver {
  ExperienceService._();
  static final instance = ExperienceService._();
  bool music = false, effects = true, vibration = true, motion = true;
  bool _ready = false, _foreground = true;
  int mainTab = 0;
  String? _route = '/';
  AudioPlayer? _music, _effect;
  DateTime? _lastEffect;
  final _storage = const FlutterSecureStorage();
  Future<void> initialize() async {
    if (_ready) return;
    _ready = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      final raw = await _storage.read(key: 'experience_v1');
      if (raw != null) {
        final data = jsonDecode(raw) as Map;
        music = data['music'] == true;
        effects = data['effects'] != false;
        vibration = data['vibration'] != false;
        motion = data['motion'] != false;
      }
    } catch (_) {
      /* Defaults are safe on a new device. */
    }
    notifyListeners();
    await _syncMusic();
  }

  Future<void> setPreference(String key, bool value) async {
    switch (key) {
      case 'music':
        music = value;
      case 'effects':
        effects = value;
      case 'vibration':
        vibration = value;
      case 'motion':
        motion = value;
    }
    notifyListeners();
    await _storage.write(
      key: 'experience_v1',
      value: jsonEncode({
        'music': music,
        'effects': effects,
        'vibration': vibration,
        'motion': motion,
      }),
    );
    await _syncMusic();
  }

  bool get _game =>
      (_route == '/' && const [0, 3, 4].contains(mainTab)) ||
      const ['/result', '/collection', '/habitat'].contains(_route);
  void selectTab(int tab) {
    mainTab = tab;
    unawaited(_syncMusic());
  }

  void routeChanged(String? route) {
    _route = route;
    unawaited(_syncMusic());
  }

  Future<AudioPlayer> _player(bool ambient) async {
    final player = AudioPlayer();
    await player.setAudioContext(
      AudioContextConfig(
        respectSilence: true,
        focus: AudioContextConfigFocus.gain,
      ).build(),
    );
    await player.setVolume(ambient ? .18 : .3);
    await player.setReleaseMode(ambient ? ReleaseMode.loop : ReleaseMode.stop);
    return player;
  }

  Future<void> _musicPending = Future.value();
  Future<void> _syncMusic() {
    final task = _musicPending.then((_) => _applyMusic());
    _musicPending = task.catchError((Object _) {});
    return task;
  }

  Future<void> _applyMusic() async {
    try {
      if (!music || !_foreground || !_game) {
        await _music?.pause();
        return;
      }
      _music ??= await _player(true);
      // Recheck after asynchronous player creation; a chat may have opened.
      if (!music || !_foreground || !_game) return;
      if (_music!.source == null) {
        await _music!.play(AssetSource('audio/garden.wav'));
      } else if (_music!.state != PlayerState.playing) {
        await _music!.resume();
      }
    } catch (_) {
      /* Audio must never block navigation or saving a record. */
    }
  }

  Future<void> celebrate() async {
    if (!_foreground || !_game) return;
    final now = DateTime.now();
    if (_lastEffect != null &&
        now.difference(_lastEffect!) < const Duration(seconds: 2)) {
      return;
    }
    _lastEffect = now;
    if (vibration) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    }
    if (!effects) return;
    try {
      _effect ??= await _player(false);
      if (_foreground && _game) {
        await _effect!.play(AssetSource('audio/discovery.wav'));
      }
    } catch (_) {
      /* The same information is always displayed as text. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) unawaited(_effect?.pause() ?? Future.value());
    unawaited(_syncMusic());
  }
}

class ExperienceNavigatorObserver extends NavigatorObserver {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    ExperienceService.instance.routeChanged(topRoute.settings.name);
  }
}
