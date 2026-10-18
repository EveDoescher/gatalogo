/// Stable ground origin shared by ruins, works, ready buildings and hit targets.
/// Upgrading changes the mesh footprint, never the building's world location.
(double, double) quintalBuildingOrigin(String kind, int x, int y) =>
    switch (kind) {
      'coop' || 'pasture' => (x + .8, y + .55),
      'pier' => (x + .7, y + .8),
      _ => (x + 1.5, y + 1.5),
    };

/// A selected world object, independent of camera position or screen widgets.
class QuintalSceneTarget {
  const QuintalSceneTarget(
    this.kind,
    this.target,
    this.role,
    this.x,
    this.y, {
    this.crop,
  });

  /// Presentation snapshot taken before a harvest request clears the plot.
  final String? crop;
  final String kind, target, role;
  final double x, y;
}
