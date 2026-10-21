import 'cat.dart';

/// Queries over one account's collection snapshot.
class CatCollection {
  CatCollection(Iterable<Cat> cats) : cats = List.unmodifiable(cats);
  final List<Cat> cats;
  List<Cat> get discoveries => cats.where((cat) => !cat.isOwned).toList();
  List<Cat> get individuals {
    final groups = <String, Cat>{};
    for (final cat in discoveries.where((c) => c.individualId != 'pending')) {
      final key = cat.individualId ?? cat.id;
      if (!groups.containsKey(key) || cat.id == key) groups[key] = cat;
    }
    return groups.values.toList();
  }

  List<Cat> photosOf(Cat cat) => cat.individualId == 'pending'
      ? [cat]
      : cats
            .where(
              (photo) =>
                  (photo.individualId ?? photo.id) ==
                  (cat.individualId ?? cat.id),
            )
            .toList();

  List<Cat> get pets => cats.where((cat) => cat.isOwned).toList();
}
