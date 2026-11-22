import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';

/// Ícono del hábito dentro de un anillo que muestra el progreso semanal.
class HabitAvatar extends StatelessWidget {
  const HabitAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.progress,
    this.size = 52,
  });

  final IconData icon;
  final Color color;

  /// Progreso de la semana (0-1). Si es `null` no se dibuja el anillo.
  final double? progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = color.withValues(alpha: 0.16);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (progress != null)
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Padding(
                padding: EdgeInsets.all(size * 0.0375),
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: size * 0.075,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: track,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(progress == null ? 0 : size * 0.14),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: track),
              child: Icon(icon, color: color, size: size * 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón "+1": registra el día de hoy. Si ya está registrado muestra una
/// palomita y al tocarlo se quita el registro.
class PlusOneButton extends StatelessWidget {
  const PlusOneButton({
    super.key,
    required this.done,
    required this.color,
    required this.onColor,
    required this.onPressed,
  });

  final bool done;
  final Color color;
  final Color onColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: done ? 'Quitar el registro de hoy' : 'Marcar hoy como hecho',
      child: Semantics(
        button: true,
        toggled: done,
        label: done ? 'Hecho hoy' : 'Sumar hoy',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 58,
          height: 44,
          decoration: BoxDecoration(
            color: done ? color : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: done ? color : scheme.outlineVariant, width: 1.5),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: done
                      ? Icon(Icons.check_rounded, key: const ValueKey('done'), color: onColor)
                      : Text(
                          '+1',
                          key: const ValueKey('plus'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Los 7 días de la semana actual. Los días pasados y hoy se pueden tocar
/// para marcarlos o desmarcarlos; los futuros están deshabilitados.
class WeekDots extends StatelessWidget {
  const WeekDots({
    super.key,
    required this.days,
    required this.today,
    required this.color,
    required this.onColor,
    required this.onToggle,
  });

  final Set<String> days;
  final DateTime today;
  final Color color;
  final Color onColor;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = daysOfWeek(today);
    final dayName = DateFormat('EEEE d', 'es');

    return Row(
      children: [
        for (final (i, day) in week.indexed)
          Expanded(
            child: Builder(
              builder: (context) {
                final done = days.contains(dayKey(day));
                final isToday = isSameDay(day, today);
                final isFuture = day.isAfter(today);
                final Color background;
                final Border? border;
                if (done) {
                  background = color;
                  border = null;
                } else if (isFuture) {
                  background = Colors.transparent;
                  border = Border.all(color: scheme.outlineVariant);
                } else {
                  background = scheme.surfaceContainerHigh;
                  border = isToday ? Border.all(color: color, width: 2) : null;
                }
                return Semantics(
                  button: !isFuture,
                  enabled: !isFuture,
                  label: '${dayName.format(day)}, ${done ? 'hecho' : 'pendiente'}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isFuture
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onToggle(day);
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        children: [
                          Text(
                            weekdayInitials[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: background,
                              border: border,
                            ),
                            child: done
                                ? Icon(Icons.check_rounded, size: 18, color: onColor)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Reconstruye su contenido cuando cambia el día (a medianoche) o cuando la
/// app vuelve a primer plano, para que "hoy" siempre sea correcto.
class TodayBuilder extends StatefulWidget {
  const TodayBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime today) builder;

  @override
  State<TodayBuilder> createState() => _TodayBuilderState();
}

class _TodayBuilderState extends State<TodayBuilder> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _schedule();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final midnight = addDays(dateOnly(now), 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, dateOnly(DateTime.now()));
}

/// Texto "3/5 días" que se pinta de verde cuando se cumple la meta.
class GoalProgressText extends StatelessWidget {
  const GoalProgressText({super.key, required this.count, required this.goal, this.style});

  final int count;
  final int goal;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = count >= goal;
    final color = met ? HabitColors.of(context).success : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count/$goal días',
          style: (style ?? theme.textTheme.bodyMedium)?.copyWith(
            color: color,
            fontWeight: met ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (met) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle_rounded, size: 16, color: color, semanticLabel: 'Meta cumplida'),
        ],
      ],
    );
  }
}
