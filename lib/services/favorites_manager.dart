import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FavoritesManager extends ChangeNotifier {
  FavoritesManager._();
  static final FavoritesManager instance = FavoritesManager._();

  final Set<String> _favorites = {};
  bool _initialized = false;

  Set<String> get favorites => Set.unmodifiable(_favorites);

  bool isFavorite(String catId) => _favorites.contains(catId);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content);
        if (list is List) {
          _favorites.addAll(list.map((e) => e.toString()));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }
  }

  Future<void> toggleFavorite(String catId) async {
    if (_favorites.contains(catId)) {
      _favorites.remove(catId);
    } else {
      _favorites.add(catId);
    }
    notifyListeners();
    await _save();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/favorites_cats.json');
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_favorites.toList()));
    } catch (e) {
      debugPrint('Erro ao salvar favoritos: $e');
    }
  }
}
