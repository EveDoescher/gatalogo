/// Bound parameters stay below SQLite's portable limit of 999 variables.
/// Deduplication avoids reading the same record twice across batches.
Iterable<List<String>> sqliteIdBatches(Iterable<String> ids) sync* {
  final unique = ids.toSet().toList();
  const size = 500;
  for (var offset = 0; offset < unique.length; offset += size) {
    yield unique.sublist(offset, (offset + size).clamp(0, unique.length));
  }
}
