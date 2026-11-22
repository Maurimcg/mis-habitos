import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Captura un PIN con teclado numérico en pantalla (y también con el
/// teclado físico). Cuando se completan los dígitos llama a [onCompleted];
/// si devuelve `false` la fila de puntos tiembla y se limpia.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCompleted,
    this.icon = Icons.lock_rounded,
    this.error,
    this.enabled = true,
    this.length = 4,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? error;
  final bool enabled;
  final int length;
  final Future<bool> Function(String pin) onCompleted;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _canType => widget.enabled && !_busy;

  Future<void> _add(String digit) async {
    if (!_canType || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length < widget.length) return;

    setState(() => _busy = true);
    final ok = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    setState(() {
      _busy = false;
      _pin = '';
    });
  }

  void _backspace() {
    if (!_canType || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _add(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.icon),
                  color: scheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: _PinDots(
                length: widget.length,
                filled: _pin.length,
                error: widget.error != null,
              ),
            ),
            SizedBox(
              height: 52,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.error == null
                      ? const SizedBox.shrink()
                      : Text(
                          widget.error!,
                          key: ValueKey(widget.error),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            _PinPad(enabled: _canType, onDigit: _add, onBackspace: _backspace),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.filled, required this.error});

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = error && filled == 0 ? scheme.error : scheme.primary;
    return Semantics(
      label: '$filled de $length dígitos ingresados',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: i < filled ? 18 : 16,
              height: i < filled ? 18 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? active : Colors.transparent,
                border: Border.all(color: i < filled ? active : scheme.outline, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.enabled, required this.onDigit, required this.onBackspace});

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: keys),
    );
    Widget digit(String d) =>
        _PadKey(enabled: enabled, onTap: () => onDigit(d), semanticLabel: d, child: Text(d));

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            const SizedBox(width: _PadKey.size, height: _PadKey.size),
            digit('0'),
            _PadKey(
              enabled: enabled,
              onTap: onBackspace,
              filled: false,
              semanticLabel: 'Borrar',
              child: const Icon(Icons.backspace_outlined),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.enabled,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.filled = true,
  });

  static const size = 74.0;

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: filled ? scheme.surfaceContainerLow : Colors.transparent,
        shape: CircleBorder(
          side: filled ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: DefaultTextStyle.merge(
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                child: IconTheme.merge(
                  data: IconThemeData(color: scheme.onSurface),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
