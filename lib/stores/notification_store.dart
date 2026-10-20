import 'package:flutter/foundation.dart';

/// One inbox snapshot shared by every screen in the signed-in session.
class NotificationStore extends ChangeNotifier {
  NotificationStore({
    required this.loadItems,
    required this.saveRead,
    this.loadPage,
  });

  final Future<List<Map<String, dynamic>>> Function() loadItems;
  final Future<void> Function(String id) saveRead;
  final Future<List<Map<String, dynamic>>> Function(String? time, String? id)?
  loadPage;
  static const pageSize = 20;
  bool hasMore = false, loadingMore = false;
  String? _cursorTime, _cursorId;
  static int newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final time = (DateTime.tryParse(b['created_at']?.toString() ?? '') ?? epoch)
        .compareTo(
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? epoch,
        );
    return time != 0 ? time : '${b['id']}'.compareTo('${a['id']}');
  }

  void _cursor(List<Map<String, dynamic>> page) {
    hasMore = loadPage != null && page.length == pageSize;
    if (page.isNotEmpty) {
      _cursorTime = page.last['created_at']?.toString();
      _cursorId = page.last['id']?.toString();
    }
  }

  Future<void> loadMore() async {
    if (_disposed ||
        loadingMore ||
        !hasMore ||
        _refreshing != null ||
        loadPage == null) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final result = await loadPage!(_cursorTime, _cursorId);
      if (_disposed || generation != _generation) return;
      _cursor(result);
      final merged = {for (final item in _items) item['id']: item};
      for (final item in result) {
        merged.putIfAbsent(
          item['id'],
          () => {
            ...item,
            if (_readIds.contains(item['id']))
              'read_at':
                  item['read_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
      _items = merged.values.toList()..sort(newestFirst);
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

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
    final result = loadPage == null
        ? await loadItems()
        : await loadPage!(null, null);
    if (_disposed || generation != _generation) return;
    _cursor(result);
    _items =
        result
            .map(
              (item) => <String, dynamic>{
                ...item,
                if (_readIds.contains(item['id']?.toString()))
                  'read_at':
                      item['read_at'] ??
                      DateTime.now().toUtc().toIso8601String(),
              },
            )
            .toList()
          ..sort(newestFirst);
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
    hasMore = loadingMore = false;
    _cursorId = _cursorTime = null;
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
