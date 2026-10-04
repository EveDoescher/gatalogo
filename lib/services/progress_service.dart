import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../stores/session_store.dart';
import 'product_api_service.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

/// Read-through cache of server outcomes; never adds a local reward.
class ProgressService extends ChangeNotifier {
  ProgressService(
    this.session, {
    ProductApiService? api,
    FlutterSecureStorage? storage,
  }) : api = api ?? ProductApiService(session),
       storage = storage ?? const FlutterSecureStorage();
  final SessionStore session;
  final ProductApiService api;
  final FlutterSecureStorage storage;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> results = [];
  bool offline = false, loadingOlder = false, hasMore = false;
  String? _owner;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _pending = Future.value();
  List<Map<String, dynamic>> get dailyMissions => _maps(summary['daily_missions']);
  List<Map<String, dynamic>> get challenges => _maps(summary['challenges']);
  List<Map<String, dynamic>> get missions => [
    ..._maps(summary['daily_missions']),
    ..._maps(summary['weekly_missions']),
  ];
  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Map<String, dynamic>? resultFor(String id) {
    for (final result in results) {
      if (result['record_id'] == id) return result;
    }
    return null;
  }

  void reset() {
    _generation++;
    _pending = Future.value();
    loadingOlder = false;
    _owner = null;
    summary = {};
    results = [];
    hasMore = false;
  }

  Future<void> refresh() {
    final generation = _generation;
    final owner = session.session?.userId;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        owner == session.session?.userId;
    final task = _pending.then((_) async {
      if (!current()) return;
      final key = 'progress_v1_${owner ?? 'guest'}';
      if (_owner != owner) {
        _owner = owner;
        summary = {};
        results = [];
        try {
          final raw = await storage.read(key: key);
          if (!current()) return;
          if (raw != null) {
            final data = jsonDecode(raw) as Map;
            summary = Map<String, dynamic>.from(data['summary'] as Map);
            results = _maps(data['results']);
          }
        } catch (_) {
          /* A broken cache cannot prevent the next server read. */
        }
      }
      if (owner == null) {
        if (current()) notifyListeners();
        return;
      }
      try {
        try {
          final timezone = await FlutterTimezone.getLocalTimezone();
          await api.put('/app/preferences', {'timezone': timezone.identifier});
        } catch (_) {
          /* Keep the last account timezone when unavailable. */
        }
        final data = await api.get('/app/progress');
        final history = await api.list('/app/progress/results?limit=200');
        if (!current()) return;
        summary = data;
        results = history;
        hasMore = history.length == 200;
        offline = false;
        await storage.write(
          key: key,
          value: jsonEncode({'summary': data, 'results': history}),
        );
      } catch (_) {
        if (current()) offline = true;
      }
      if (current()) notifyListeners();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> loadOlder() async {
    if (loadingOlder || !hasMore || results.isEmpty) return;
    final owner = session.session?.userId;
    final generation = _generation;
    bool current() => !_disposed && owner == session.session?.userId && generation == _generation;
    loadingOlder = true;
    notifyListeners();
    try {
      final page = await api.list('/app/progress/results?limit=200&cursor=${results.last['event_id']}');
      if (!current()) return;
      final ids = results.map((e) => e['event_id']).toSet();
      results.addAll(page.where((e) => !ids.contains(e['event_id'])));
      hasMore = page.length == 200;
    } catch (_) { if (current()) offline = true; }
    finally { if (current()) { loadingOlder = false; notifyListeners(); } }
  }

  Future<void> track(String name) async {
    if (!session.isSignedIn) return;
    try {
      await api.post('/app/progress/experience', {'event_id': const Uuid().v4(), 'name': name});
    } catch (_) { /* Optional measurement never blocks the experience. */ }
  }

  Future<Map<String, dynamic>> fetchResult(String eventId) async {
    final owner = session.session?.userId;
    final result = await api.get('/app/progress/results/$eventId');
    if (!_disposed && owner == session.session?.userId) {
      results.removeWhere((e) => e['event_id'] == eventId);
      results.insert(0, result);
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
