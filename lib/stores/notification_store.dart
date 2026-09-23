import 'package:flutter/foundation.dart';

/// One inbox snapshot shared by every screen in the signed-in session.
class NotificationStore extends ChangeNotifier {
  NotificationStore({required this.loadItems, required this.saveRead});

  final Future<List<Map<String, dynamic>>> Function() loadItems;
  final Future<void> Function(String id) saveRead;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _readIds = {};
  Future<void>? _refreshing;
  int _generation = 0;
  bool _disposed = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => item['read_at'] == null).length;

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_refreshing != null) return _refreshing!;
    late final Future<void> request;
    request = _load().whenComplete(() {
      if (identical(_refreshing, request)) _refreshing = null;
    });
    return _refreshing = request;
  }

  Future<void> _load() async {
    final generation = _generation;
    final result = await loadItems();
    if (_disposed || generation != _generation) return;
    _items = result
        .map(
          (item) => <String, dynamic>{
            ...item,
            if (_readIds.contains(item['id']?.toString()))
              'read_at':
                  item['read_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final generation = _generation;
    await saveRead(id);
    if (_disposed || generation != _generation) return;
    _readIds.add(id);
    _items = _items
        .map(
          (item) => item['id']?.toString() == id
              ? <String, dynamic>{
                  ...item,
                  'read_at': DateTime.now().toUtc().toIso8601String(),
                }
              : item,
        )
        .toList();
    notifyListeners();
  }

  void clear() {
    _generation++;
    _refreshing = null;
    _items = [];
    _readIds.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
