import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reports the laid-out height, including changes to text size and content.
class QuintalMeasuredHeight extends SingleChildRenderObjectWidget {
  const QuintalMeasuredHeight({
    super.key,
    required this.onChanged,
    required super.child,
  });
  final ValueChanged<double> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderQuintalMeasuredHeight(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderQuintalMeasuredHeight renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class RenderQuintalMeasuredHeight extends RenderProxyBox {
  RenderQuintalMeasuredHeight(this.onChanged);
  ValueChanged<double> onChanged;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported == height) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _reported == height) onChanged(height);
    });
  }
}

/// Bottom inset belongs to the navigation bar and is applied exactly once.
class QuintalBottomTray extends StatelessWidget {
  const QuintalBottomTray({
    super.key,
    required this.child,
    required this.onExtentChanged,
    this.margin = EdgeInsets.zero,
  });
  final Widget child;
  final ValueChanged<double> onExtentChanged;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Positioned(
      left: margin.left,
      right: margin.right,
      bottom: padding.bottom + margin.bottom,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return QuintalMeasuredHeight(
            onChanged: (height) => onExtentChanged(height + margin.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  0,
                  MediaQuery.sizeOf(context).height -
                      padding.vertical -
                      margin.bottom -
                      100,
                ),
              ),
              child: SingleChildScrollView(child: child),
            ),
          );
        },
      ),
    );
  }
}

class QuintalFloatingMenu extends StatelessWidget {
  const QuintalFloatingMenu({
    super.key,
    required this.trayExtent,
    required this.button,
    required this.actions,
  });
  final double trayExtent;
  final Widget button;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final bottom = padding.bottom + trayExtent + 8;
    return Positioned(
      right: padding.right + 16,
      bottom: bottom,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            52,
            MediaQuery.sizeOf(context).height - padding.top - bottom - 8,
          ),
          maxWidth: math.max(
            0,
            MediaQuery.sizeOf(context).width - padding.horizontal - 32,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (actions.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions,
                  ),
                ),
              ),
            button,
          ],
        ),
      ),
    );
  }
}
