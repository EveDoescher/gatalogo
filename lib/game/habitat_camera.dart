import 'dart:math' as math;
import 'dart:ui';

/// Isometric projection and viewport limits, independent from the scene and storage.
class HabitatCamera {
  Size viewport = Size.zero;
  double zoom = 1;
  Offset pan = Offset.zero;

  double get tileWidth =>
      math.min(viewport.width / 8.7, viewport.height / 5.7) * zoom;
  // The source artwork uses a 30-degree orthographic camera (2:1 ground tiles).
  double get tileHeight => tileWidth * 0.5;
  double get boardTop => (viewport.height - 8 * tileHeight) / 2 + pan.dy;

  Offset cellTop(int x, int y) => Offset(
    viewport.width / 2 + (x - y) * tileWidth / 2 + pan.dx,
    boardTop + (x + y) * tileHeight / 2,
  );

  Offset groundAnchor(int x, int y) =>
      cellTop(x, y) + Offset(0, tileHeight / 2);
  Offset groundPoint(double x, double y) =>
      groundAnchor(x.floor(), y.floor()) +
      Offset(
        (x - x.floor() - y + y.floor()) * tileWidth / 2,
        (x - x.floor() + y - y.floor()) * tileHeight / 2,
      );

  (int, int) cellAt(Offset point) {
    final dx = (point.dx - viewport.width / 2 - pan.dx) / (tileWidth / 2);
    final dy = (point.dy - boardTop) / (tileHeight / 2);
    final x = ((dx + dy) / 2).floor();
    final y = ((dy - dx) / 2).floor();
    return (x, y);
  }

  /// The scenery boundary belongs to the world. Zoom changes its projected
  /// edges, not how far into that world the player is allowed to explore.
  Rect panBounds({
    required bool productionEnabled,
    required Iterable<(int, int, int, int)> productionAreas,
  }) {
    final center = Offset(viewport.width / 2, viewport.height / 2);
    var left = -viewport.width * .4, top = -viewport.height * .4;
    var right = viewport.width * (!productionEnabled ? 1.4 : 2.4);
    var bottom = viewport.height * (!productionEnabled ? 1.4 : 1.9);
    if (productionEnabled) {
      // Keep every production space reachable, including its anchored actions
      // on narrow screens. Bounds live at zoom 1 so zooming preserves the
      // world edge instead of snapping back toward the original cat yard.
      for (final area in productionAreas) {
        for (final x in [area.$1.toDouble(), (area.$1 + area.$3).toDouble()]) {
          for (final y in [
            area.$2.toDouble(),
            (area.$2 + area.$4).toDouble(),
          ]) {
            final point = center + (groundPoint(x, y) - pan - center) / zoom;
            left = math.min(left, point.dx - viewport.width * .75);
            right = math.max(right, point.dx + viewport.width * .75);
            top = math.min(top, point.dy - viewport.height);
            bottom = math.max(bottom, point.dy + viewport.height);
          }
        }
      }
    }
    return Rect.fromLTRB(
      viewport.width - (center.dx + (right - center.dx) * zoom),
      viewport.height - (center.dy + (bottom - center.dy) * zoom),
      -(center.dx + (left - center.dx) * zoom),
      -(center.dy + (top - center.dy) * zoom),
    );
  }

  Offset _limitPan(Offset value, Rect bounds) {
    return Offset(
      value.dx.clamp(bounds.left, bounds.right),
      value.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  void move(Offset delta, Rect bounds) {
    pan += delta;
    pan = _limitPan(pan, bounds);
  }

  void scale(
    double value,
    Offset focus, {
    required bool productionEnabled,
    required Iterable<(int, int, int, int)> productionAreas,
  }) {
    final ratio = value.clamp(0.8, 1.9) / zoom;
    zoom *= ratio;
    pan = Offset(
      focus.dx -
          viewport.width / 2 -
          (focus.dx - viewport.width / 2 - pan.dx) * ratio,
      focus.dy -
          viewport.height / 2 -
          (focus.dy - viewport.height / 2 - pan.dy) * ratio,
    );
    pan = _limitPan(
      pan,
      panBounds(
        productionEnabled: productionEnabled,
        productionAreas: productionAreas,
      ),
    );
  }

  /// Inverse projection includes trees rooted just beyond the viewport edge.
  Rect get sceneryRegion {
    final cells = [
      for (final point in [
        Offset.zero,
        Offset(viewport.width, 0),
        Offset(0, viewport.height),
        Offset(viewport.width, viewport.height),
      ])
        (() {
          final dx = (point.dx - viewport.width / 2 - pan.dx) / (tileWidth / 2);
          final dy = (point.dy - boardTop) / (tileHeight / 2);
          return Offset((dx + dy) / 2, (dy - dx) / 2);
        })(),
    ];
    return Rect.fromLTRB(
      cells.map((c) => c.dx).reduce(math.min).floorToDouble() - 4,
      cells.map((c) => c.dy).reduce(math.min).floorToDouble() - 4,
      cells.map((c) => c.dx).reduce(math.max).ceilToDouble() + 4,
      cells.map((c) => c.dy).reduce(math.max).ceilToDouble() + 4,
    );
  }
}
