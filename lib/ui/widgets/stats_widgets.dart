import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../domain/habit_stats.dart';

/// Tarjeta con una cifra destacada (racha, total, porcentaje...).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: theme.textTheme.headlineSmall),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barras con los días cumplidos por semana y una línea con la meta.
///
/// El valor de la semana seleccionada se lee en el encabezado (no depende de
/// un tooltip) y se puede tocar o arrastrar para elegir otra semana.
class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({super.key, required this.weeks, required this.goal, required this.color});

  final List<WeekSummary> weeks;
  final int goal;
  final Color color;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  int? _selected;

  int get _selectedIndex =>
      (_selected ?? widget.weeks.length - 1).clamp(0, widget.weeks.length - 1);

  void _select(Offset position, double width) {
    final slot = width / widget.weeks.length;
    final index = (position.dx / slot).floor().clamp(0, widget.weeks.length - 1);
    if (index != _selectedIndex) HapticFeedback.selectionClick();
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = widget.weeks[_selectedIndex];
    final end = addDays(week.start, 6);
    final range = DateFormat('d MMM', 'es');
    final isCurrent = _selectedIndex == widget.weeks.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCurrent ? 'Esta semana' : '${range.format(week.start)} – ${range.format(end)}',
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${week.count}', style: theme.textTheme.headlineSmall),
              TextSpan(
                text: ' de ${widget.goal} días',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (week.goalMet)
                TextSpan(
                  text: '  · meta cumplida',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Días cumplidos por semana: ${widget.weeks.map((w) => '${range.format(w.start)}: ${w.count}').join(', ')}',
          excludeSemantics: true,
          child: SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const axisWidth = 22.0;
                final plotWidth = constraints.maxWidth - axisWidth;
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _select(d.localPosition, plotWidth),
                        onHorizontalDragUpdate: (d) => _select(d.localPosition, plotWidth),
                        child: CustomPaint(
                          size: Size(plotWidth, 150),
                          painter: _BarsPainter(
                            weeks: widget.weeks,
                            goal: widget.goal,
                            selected: _selectedIndex,
                            color: widget.color,
                            baseline: scheme.outline.withValues(alpha: 0.5),
                            grid: scheme.outlineVariant,
                            label: scheme.onSurfaceVariant,
                            labelStyle: theme.textTheme.labelSmall!,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: axisWidth,
                      child: CustomPaint(
                        size: const Size(axisWidth, 150),
                        painter: _AxisPainter(
                          goal: widget.goal,
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

const _labelBand = 20.0;
const _topPad = 8.0;

double _yFor(double value, double height) {
  final plot = height - _labelBand - _topPad;
  return _topPad + plot * (1 - value / 7);
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.weeks,
    required this.goal,
    required this.selected,
    required this.color,
    required this.baseline,
    required this.grid,
    required this.label,
    required this.labelStyle,
  });

  final List<WeekSummary> weeks;
  final int goal;
  final int selected;
  final Color color;
  final Color baseline;
  final Color grid;
  final Color label;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = _yFor(0, size.height);
    final slot = size.width / weeks.length;
    final barWidth = (slot * 0.56).clamp(6.0, 28.0);

    // Línea de la meta: sólida y fina, para no competir con las barras.
    final goalY = _yFor(goal.toDouble(), size.height);
    canvas.drawLine(
      Offset(0, goalY),
      Offset(size.width, goalY),
      Paint()
        ..color = grid
        ..strokeWidth = 1.5,
    );

    for (final (i, week) in weeks.indexed) {
      final centerX = slot * i + slot / 2;
      if (week.count > 0) {
        final top = _yFor(week.count.toDouble(), size.height);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTRB(centerX - barWidth / 2, top, centerX + barWidth / 2, baseY),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = i == selected ? color : color.withValues(alpha: 0.38),
        );
      }

      final painter = TextPainter(
        text: TextSpan(
          text: '${week.start.day}/${week.start.month}',
          style: labelStyle.copyWith(
            color: label,
            fontSize: 10,
            fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(centerX - painter.width / 2, baseY + 6));
    }

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.weeks != weeks ||
      old.selected != selected ||
      old.color != color ||
      old.goal != goal ||
      old.grid != grid ||
      old.label != label;
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.goal, required this.style});

  final int goal;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    for (final value in {0, goal, 7}) {
      final painter = TextPainter(
        text: TextSpan(text: '$value', style: style.copyWith(fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final y = _yFor(value.toDouble(), size.height) - painter.height / 2;
      painter.paint(canvas, Offset(size.width - painter.width, y));
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) => old.goal != goal || old.style != style;
}

/// Historial de las últimas semanas: columnas = semanas, filas = días.
/// Tocar un día lo marca o desmarca (para corregir olvidos).
class HistoryHeatmap extends StatelessWidget {
  const HistoryHeatmap({
    super.key,
    required this.days,
    required this.today,
    required this.color,
    required this.onToggle,
    this.createdAt,
    this.weeks = 16,
  });

  final Set<String> days;
  final DateTime today;
  final Color color;

  /// Los días anteriores a la creación del hábito se pintan más tenues.
  final DateTime? createdAt;
  final ValueChanged<DateTime> onToggle;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstMonday = addDays(startOfWeek(today), -7 * (weeks - 1));
    final tooltipFormat = DateFormat("EEEE d 'de' MMMM", 'es');
    final monthFormat = DateFormat('MMM', 'es');
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 10,
    );
    const gap = 3.0;
    const labelWidth = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = ((constraints.maxWidth - labelWidth) / weeks - gap).clamp(8.0, 22.0);
        final columnWidth = cell + gap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meses encima de la primera semana de cada mes.
            SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var w = 0; w < weeks; w++)
                    if (w == 0 ||
                        addDays(firstMonday, 7 * w).month !=
                            addDays(firstMonday, 7 * (w - 1)).month)
                      Positioned(
                        left: labelWidth + w * columnWidth,
                        child: Text(
                          monthFormat.format(addDays(firstMonday, 7 * w)),
                          style: labelStyle,
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        SizedBox(
                          height: columnWidth,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(d.isEven ? weekdayInitials[d] : '', style: labelStyle),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var w = 0; w < weeks; w++)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        _HeatCell(
                          day: addDays(firstMonday, 7 * w + d),
                          size: cell,
                          gap: gap,
                          today: today,
                          done: days.contains(dayKey(addDays(firstMonday, 7 * w + d))),
                          color: color,
                          empty:
                              createdAt != null &&
                                  addDays(firstMonday, 7 * w + d).isBefore(dateOnly(createdAt!))
                              ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
                              : scheme.surfaceContainerHighest,
                          ring: scheme.onSurface,
                          tooltip: tooltipFormat,
                          onToggle: onToggle,
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendSwatch(color: scheme.surfaceContainerHighest),
                const SizedBox(width: 6),
                Text('Pendiente', style: labelStyle),
                const SizedBox(width: 14),
                _LegendSwatch(color: color),
                const SizedBox(width: 6),
                Text('Hecho', style: labelStyle),
                const Spacer(),
                Flexible(
                  child: Text(
                    'Toca para corregir',
                    style: labelStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.size,
    required this.gap,
    required this.today,
    required this.done,
    required this.color,
    required this.empty,
    required this.ring,
    required this.tooltip,
    required this.onToggle,
  });

  final DateTime day;
  final double size;
  final double gap;
  final DateTime today;
  final bool done;
  final Color color;
  final Color empty;
  final Color ring;
  final DateFormat tooltip;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final future = day.isAfter(today);
    final isToday = isSameDay(day, today);
    final box = Container(
      width: size,
      height: size,
      margin: EdgeInsets.only(right: gap, bottom: gap),
      decoration: BoxDecoration(
        color: future ? Colors.transparent : (done ? color : empty),
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: ring, width: 1.5) : null,
      ),
    );
    if (future) return box;
    return Tooltip(
      message: '${tooltip.format(day)} · ${done ? 'hecho' : 'pendiente'}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(day);
        },
        child: box,
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
  );
}
