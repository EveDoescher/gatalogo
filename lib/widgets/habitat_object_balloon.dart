import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';

/// Shared world-space balloon for editing and caring. Measures the actual
/// content before placing it, so short actions stay attached to their object.
class HabitatObjectBalloon extends SingleChildRenderObjectWidget {
  const HabitatObjectBalloon({
    super.key,
    required this.anchor,
    required this.objectHeight,
    this.maxWidth = 280,
    this.safeInsets = const EdgeInsets.fromLTRB(8, 78, 8, 90),
    this.docked = false,
    this.showPointer = true,
    this.onReframeChanged,
    required super.child,
  });
  final Offset anchor;
  final double objectHeight, maxWidth;
  final EdgeInsets safeInsets;
  final bool docked, showPointer;

  /// Camera translation to reveal actions without detaching the world anchor.
  final ValueChanged<Offset>? onReframeChanged;
  @override
  RenderObject createRenderObject(BuildContext context) => HabitatBalloonLayout(
    anchor,
    objectHeight,
    maxWidth,
    safeInsets,
    docked,
    showPointer,
    onReframeChanged,
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant HabitatBalloonLayout renderObject,
  ) {
    renderObject.update(
      anchor,
      objectHeight,
      maxWidth,
      safeInsets,
      docked,
      showPointer,
      onReframeChanged,
    );
  }
}

class HabitatBalloonLayout extends RenderShiftedBox {
  HabitatBalloonLayout(
    this.anchor,
    this.objectHeight,
    this.maxWidth,
    this.insets,
    this.docked,
    this.showPointer,
    this.onReframeChanged,
  ) : super(null);
  Offset anchor;
  double objectHeight, maxWidth;
  EdgeInsets insets;
  bool docked, showPointer;
  bool above = true;
  ValueChanged<Offset>? onReframeChanged;
  Offset? _reportedReframe;
  void update(
    Offset a,
    double h,
    double w,
    EdgeInsets s,
    bool d,
    bool pointer,
    ValueChanged<Offset>? reframe,
  ) {
    onReframeChanged = reframe;
    if (anchor == a &&
        objectHeight == h &&
        maxWidth == w &&
        insets == s &&
        docked == d &&
        showPointer == pointer) {
      return;
    }
    anchor = a;
    objectHeight = h;
    maxWidth = w;
    insets = s;
    if (docked != d) _reportedReframe = null;
    docked = d;
    showPointer = pointer;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final width = math.max(
      0.0,
      math.min(maxWidth, size.width - insets.horizontal),
    );
    child!.layout(
      BoxConstraints(
        maxWidth: width,
        maxHeight: math.max(0, size.height - insets.vertical - 24),
      ),
      parentUsesSize: true,
    );
    final top = anchor.dy - objectHeight;
    if (docked) {
      (child!.parentData as BoxParentData).offset = Offset(
        (size.width - child!.size.width) / 2,
        size.height - insets.bottom - child!.size.height,
      );
      _reportReframe(Offset.zero);
      return;
    }
    // Keep the same world-relative attachment throughout pan/zoom. Clamping or
    // flipping at viewport edges makes actions appear attached to the camera.
    above = true;
    final x = anchor.dx - child!.size.width / 2;
    final y = top - child!.size.height - 10;
    (child!.parentData as BoxParentData).offset = Offset(
      x.toDouble(),
      y.toDouble(),
    );
    final bounds = (Offset(x, y) & child!.size).expandToInclude(
      Rect.fromLTWH(anchor.dx, anchor.dy, 1, 1),
    );
    final visible = _viewport.deflate(1);
    final dx = bounds.left < visible.left || bounds.right > visible.right
        ? visible.center.dx - bounds.center.dx
        : 0.0;
    // Include the object in the framing, not only its controls.
    final dy = bounds.top < visible.top || bounds.bottom > visible.bottom
        ? (bounds.height <= visible.height
              ? visible.center.dy - bounds.center.dy
              : visible.top - bounds.top)
        : 0.0;
    _reportReframe(Offset(dx, dy));
  }

  void _reportReframe(Offset delta) {
    if (onReframeChanged == null || _reportedReframe == delta) return;
    _reportedReframe = delta;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _reportedReframe == delta) onReframeChanged?.call(delta);
    });
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => docked
      ? null
      : _targetVisible
      ? _viewport
      : Rect.zero;

  Rect get _viewport => Rect.fromLTRB(
    insets.left,
    insets.top,
    size.width - insets.right,
    size.height - insets.bottom,
  );

  bool get _targetVisible => (Offset.zero & size).contains(anchor);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!docked && (!_targetVisible || !_viewport.contains(position))) {
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (docked) {
      super.paint(context, offset);
      return;
    }
    if (!_targetVisible) return;
    context.pushClipRect(needsCompositing, offset, _viewport, _paintBalloon);
  }

  void _paintBalloon(PaintingContext context, Offset offset) {
    if (!showPointer || docked) {
      super.paint(context, offset);
      return;
    }
    final p = (child!.parentData as BoxParentData).offset;
    final x = anchor.dx.clamp(p.dx + 18, p.dx + child!.size.width - 18);
    final y = above ? p.dy + child!.size.height : p.dy;
    final path = Path()
      ..moveTo(x - 8, y)
      ..lineTo(x, y + (above ? 9 : -9))
      ..lineTo(x + 8, y)
      ..close();
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    context.canvas.drawPath(path, Paint()..color = AppColors.surface);
    context.canvas.drawPath(
      Path()
        ..moveTo(x - 8, y)
        ..lineTo(x, y + (above ? 9 : -9))
        ..lineTo(x + 8, y),
      Paint()
        ..color = const Color(0xffa38b61)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    context.canvas.restore();
    super.paint(context, offset);
  }
}

class HabitatBalloonSurface extends StatelessWidget {
  const HabitatBalloonSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xffb19a70),
      borderRadius: BorderRadius.circular(23),
      boxShadow: [
        BoxShadow(
          color: AppColors.textTitle.withValues(alpha: .16),
          offset: const Offset(0, 5),
          blurRadius: 8,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xffa38b61), width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ),
  );
}

class HabitatBalloonAction extends StatefulWidget {
  const HabitatBalloonAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.artwork,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Widget? artwork;
  @override
  State<HabitatBalloonAction> createState() => _HabitatBalloonActionState();
}

class _HabitatBalloonActionState extends State<HabitatBalloonAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.label == 'Deselecionar'
        ? 112 * MediaQuery.textScalerOf(context).scale(14) / 14
        : 72 * MediaQuery.textScalerOf(context).scale(14) / 14,
    child: Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: Tooltip(
        message: widget.label,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 90),
                  width: 48,
                  height: 48,
                  transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.onPressed == null
                        ? const Color(0xffebe5d4)
                        : const Color(0xffedf2cf),
                    border: Border.all(
                      color: widget.onPressed == null
                          ? const Color(0xffc9c1ac)
                          : const Color(0xff91a566),
                      width: 1.5,
                    ),
                    boxShadow: _pressed
                        ? []
                        : [
                            BoxShadow(
                              color: widget.onPressed == null
                                  ? const Color(0xffc9c1ac)
                                  : const Color(0xff9dad76),
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Opacity(
                    opacity: widget.onPressed == null ? .42 : 1,
                    child:
                        widget.artwork ??
                        Icon(widget.icon, size: 24, color: AppColors.greenLink),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: widget.onPressed == null
                        ? AppColors.textLight
                        : AppColors.textTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
