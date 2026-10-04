/// The neighbor order is west, east, north, south in yard coordinates.
(String, int) pathSprite(String stem, List<bool> neighbors) {
  if (!stem.startsWith('path_')) return (stem, 0);
  final connected = neighbors.where((value) => value).length;
  if (connected == 1) return ('${stem}End', neighbors.indexOf(true));
  if (connected == 2) {
    if (neighbors[0] && neighbors[1]) return (stem, 0);
    if (neighbors[2] && neighbors[3]) return (stem, 1);
    if (neighbors[0] && neighbors[2]) return ('${stem}Corner', 0);
    if (neighbors[1] && neighbors[2]) return ('${stem}Corner', 1);
    if (neighbors[1] && neighbors[3]) return ('${stem}Corner', 2);
    return ('${stem}Corner', 3);
  }
  if (connected >= 3 && stem == 'path_stone') return ('${stem}Circle', 0);
  return (stem, 0);
}
