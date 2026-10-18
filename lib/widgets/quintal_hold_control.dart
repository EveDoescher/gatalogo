import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Pointer hold, keyboard hold and an accessible toggle share one control.
class QuintalHoldControl extends StatefulWidget {
  const QuintalHoldControl({
    super.key,
    required this.held,
    required this.onChanged,
  });
  final bool held;
  final ValueChanged<bool>? onChanged;
  @override
  State<QuintalHoldControl> createState() => _QuintalHoldControlState();
}

class _QuintalHoldControlState extends State<QuintalHoldControl> {
  final _pointers = <int>{};
  final _keys = <LogicalKeyboardKey>{};
  bool _focused = false;

  void _publish() =>
      widget.onChanged?.call(_pointers.isNotEmpty || _keys.isNotEmpty);

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onChanged != null,
    label: 'Subir a faixa. Toque para alternar entre subir e descer.',
    value: widget.held ? 'Subindo' : 'Descendo',
    onTap: widget.onChanged == null
        ? null
        : () => widget.onChanged!(!widget.held),
    child: ExcludeSemantics(
      child: Focus(
        canRequestFocus: widget.onChanged != null,
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (!focused) {
            _keys.clear();
            _publish();
          }
        },
        onKeyEvent: (_, event) {
          if (widget.onChanged == null ||
              !{
                LogicalKeyboardKey.space,
                LogicalKeyboardKey.enter,
              }.contains(event.logicalKey)) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) _keys.add(event.logicalKey);
          if (event is KeyUpEvent) _keys.remove(event.logicalKey);
          _publish();
          return KeyEventResult.handled;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: widget.onChanged == null
              ? null
              : (event) {
                  _pointers.add(event.pointer);
                  _publish();
                },
          onPointerUp: (event) {
            _pointers.remove(event.pointer);
            _publish();
          },
          onPointerCancel: (event) {
            _pointers.remove(event.pointer);
            _publish();
          },
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 90),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.onChanged == null
                  ? AppColors.cardBackground
                  : widget.held
                  ? AppColors.textTitle
                  : AppColors.greenLink,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? AppColors.primaryDark : AppColors.surface,
                width: 3,
              ),
            ),
            child: Text(
              widget.onChanged == null
                  ? 'Conferindo…'
                  : widget.held
                  ? 'Solte para descer'
                  : 'Segurar para subir',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.onChanged == null
                    ? AppColors.textTitle
                    : AppColors.surface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
