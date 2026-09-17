import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/cat_database.dart';
import '../stores/session_store.dart';
import 'product_api_service.dart';

class FavoritesManager extends ChangeNotifier {
  FavoritesManager._();
  static final FavoritesManager instance = FavoritesManager._();

  final Set<String> _favorites = {};
  final CatDatabase _database = CatDatabase.instance;
  bool _initialized = false;

  Set<String> get favorites => Set.unmodifiable(_favorites);

  bool isFavorite(String catId) => _favorites.contains(catId);

  Future<void> initialize({SessionStore? sessionStore}) async {
    if (!_initialized) {
      _initialized = true;
      try {
        final file = await _getFile();
        if (await file.exists()) {
          final content = await file.readAsString();
          final list = jsonDecode(content);
          if (list is List) {
            _favorites.addAll(list.map((e) => e.toString()));
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar favoritos locais: $e');
      }

      try {
        final cats = await _database.getCats();
        for (final cat in cats) {
          if (cat.isFavorite) {
            _favorites.add(cat.id);
          }
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar favoritos do banco local: $e');
      }
      notifyListeners();
    }

    if (sessionStore != null && sessionStore.isSignedIn) {
      await syncWithServer(sessionStore);
    }
  }

  Future<void> toggleFavorite(String catId, {SessionStore? sessionStore}) async {
    final bool willBeFavorite = !_favorites.contains(catId);
    if (willBeFavorite) {
      _favorites.add(catId);
    } else {
      _favorites.remove(catId);
    }
    notifyListeners();

    try {
      await _database.updateCatFavorite(catId, willBeFavorite);
    } catch (e) {
      debugPrint('Erro ao atualizar favorito no banco: $e');
    }

    await _save();

    if (sessionStore != null && sessionStore.isSignedIn) {
      try {
        final api = ProductApiService(sessionStore);
        await api.put('/app/favorites', {'favorites': _favorites.toList()});
      } catch (e) {
        debugPrint('Erro ao salvar favorito na nuvem: $e');
      }
    }
  }

  Future<void> syncWithServer(SessionStore sessionStore) async {
    if (!sessionStore.isSignedIn) return;
    try {
      final api = ProductApiService(sessionStore);
      final response = await api.get('/app/favorites');
      final remoteList = (response['favorites'] as List?)?.map((e) => e.toString()).toSet() ?? {};

      final initialCount = _favorites.length;
      final bool hadLocalExclusives = _favorites.any((id) => !remoteList.contains(id));

      _favorites.addAll(remoteList);

      for (final id in remoteList) {
        await _database.updateCatFavorite(id, true);
      }

      if (_favorites.length != initialCount) {
        await _save();
        notifyListeners();
      }

      if (hadLocalExclusives) {
        await api.put('/app/favorites', {'favorites': _favorites.toList()});
      }
    } catch (e) {
      debugPrint('Erro na sincronizacao de favoritos com o servidor: $e');
    }
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
      debugPrint('Erro ao salvar arquivo de favoritos: $e');
    }
  }
}
