import 'package:flutter/foundation.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../services/location_service.dart';

/// Commands for one collection entry; dialogs and navigation stay in the view.
class CatDetailsController extends ChangeNotifier {
  CatDetailsController(this.store);
  final CatStore store;
  bool _busy = false, _disposed = false;
  bool get busy => _busy;
  Future<void> _run(Future<void> Function() command) async {
    if (_disposed) return;
    _busy = true;
    notifyListeners();
    try {
      await command();
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> rename(Cat cat, String? name) =>
      _run(() => store.updateCatName(cat.id, name));
  Future<void> remove(Cat cat) => _run(() => store.deleteCat(cat.id));
  Future<void> notes(Cat cat, String? text) =>
      _run(() => store.updateCatNotes(cat.id, text));
  Future<void> enrichLocation(Cat cat) async {
    if (cat.latitude == null || cat.longitude == null) return;
    final current = cat.locationName?.trim() ?? '';
    if (current.isNotEmpty &&
        !RegExp(r'\b\d+\b').hasMatch(current) &&
        current.split(',').length > 3) {
      return;
    }
    final enriched = await LocationService.getLocationName(
      cat.latitude!,
      cat.longitude!,
    );
    if (!_disposed &&
        enriched != null &&
        enriched.isNotEmpty &&
        enriched != current) {
      await store.updateCatLocation(
        cat.id,
        latitude: cat.latitude!,
        longitude: cat.longitude!,
        locationName: enriched,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
