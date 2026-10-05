part of 'habitat_game.dart';

extension HabitatInteractions on HabitatGame {
  static const _furniture = {
    'cat_bed',
    'floor_bed',
    'large_log',
    'round_stump',
    'play_crate',
    'wood_platform',
    'canvas_shelter',
    'canvas_retreat',
    'closed_tent',
  };

  String preference(String catId) =>
      catId.codeUnits.fold(0, (a, b) => a + b).isEven
      ? 'descanso'
      : 'brincadeira';

  void _visitFurniture(String catId, HabitatCatMotion walk, {String? itemId}) {
    if (walk.targetItemId != null) return;
    final occupied = _catWalks.values.map((walk) => walk.targetItemId).toSet();
    final options =
        habitat.items
            .where(
              (item) =>
                  item.isPlaced &&
                  _furniture.contains(item.sku) &&
                  !occupied.contains(item.id) &&
                  (itemId == null || item.id == itemId),
            )
            .toList()
          ..shuffle(_random);
    options.sort(
      (a, b) =>
          (habitat.definition(a.sku).category == preference(catId) ? 0 : 1)
              .compareTo(
                habitat.definition(b.sku).category == preference(catId) ? 0 : 1,
              ),
    );
    for (final item in options) {
      final route = habitat.routeTo(walk.next, habitat.accessCells(item));
      if (route == null) continue;
      final activity = habitat.definition(item.sku).category == 'brincadeira'
          ? 'play'
          : 'rest';
      if (activity == 'play') {
        unawaited(sprites.catAnimations.preload(HabitatCatClip.play));
      }
      unawaited(
        walk.goTo(
          item.id,
          route,
          activity,
          placement: (item.x!, item.y!, item.rotation),
        ),
      );
      return;
    }
  }

  bool inviteToFurniture(String itemId) {
    for (final entry in _catWalks.entries) {
      if (entry.value.targetItemId != null) continue;
      _visitFurniture(entry.key, entry.value, itemId: itemId);
      if (entry.value.targetItemId == itemId) return true;
    }
    return false;
  }

  Future<void> feedCat(String catId, {bool treat = false}) async {
    if (_feeding) {
      throw const ProductApiException(
        'Um gato já está indo comer. Aguarde um instante.',
      );
    }
    final walk = _catWalks[catId];
    if (walk == null || editing) {
      throw const ProductApiException(
        'Coloque este gato no quintal e saia do modo de edição.',
      );
    }
    if (!habitat.session.isSignedIn || habitat.offline) {
      throw const ProductApiException(
        'Conecte sua conta para alimentar os gatos.',
      );
    }
    final occupied = _catWalks.values
        .where((other) => other != walk)
        .map((other) => other.targetItemId)
        .toSet();
    final choices = <(HabitatItem, List<(int, int)>)>[];
    for (final bowl in habitat.items.where(
      (item) =>
          item.isPlaced &&
          item.sku == 'food_bowl' &&
          !occupied.contains(item.id),
    )) {
      final route = habitat.routeTo(walk.next, habitat.accessCells(bowl));
      if (route != null) choices.add((bowl, route));
    }
    choices.sort((a, b) => a.$2.length.compareTo(b.$2.length));
    if (choices.isEmpty) {
      throw const ProductApiException(
        'Coloque um potinho com um caminho livre até ele.',
      );
    }
    _feeding = true;
    final (bowl, route) = choices.first;
    try {
      await Future.wait([
        sprites.catAnimations.preload(HabitatCatClip.eat),
        sprites.ready(sprites.keyFor('bowl-cereal', bowl.rotation)),
      ]);
      if (_removed) return;
      final arrived = walk.goTo(
        bowl.id,
        route,
        'feed',
        placement: (bowl.x!, bowl.y!, bowl.rotation),
      );
      if (reducedMotion) {
        walk.current = walk.next = route.lastOrNull ?? walk.next;
        walk.progress = 0;
        walk.route.clear();
        walk.advance(0, _random, habitat.isFreeForCat);
      }
      if (!await arrived || _removed) {
        throw const ProductApiException(
          'O caminho mudou. Tente alimentar novamente.',
        );
      }
      await habitat.interact(treat ? 'treat' : 'feed', catId, bowlId: bowl.id);
      walk.finishFeeding();
    } catch (_) {
      walk.cancelVisit();
      rethrow;
    } finally {
      _feeding = false;
    }
  }
}
