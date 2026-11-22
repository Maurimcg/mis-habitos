import '../core/dates.dart';

/// Resumen de una semana: cuántos días se cumplió el hábito.
class WeekSummary {
  const WeekSummary({required this.start, required this.count, required this.goal});

  /// Lunes de la semana.
  final DateTime start;
  final int count;
  final int goal;

  bool get goalMet => count >= goal;
}

/// Estadísticas de un hábito calculadas a partir de sus días cumplidos.
///
/// Es lógica pura (sin base de datos ni Flutter), así se prueba fácilmente.
class HabitStats {
  HabitStats._(
    this._countsByWeek,
    this._today, {
    required this.goal,
    required this.weekCount,
    required this.doneToday,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalDays,
    required this.weeksMet,
    required this.weeksConsidered,
  });

  /// Calcula las estadísticas.
  ///
  /// * [days]: días cumplidos en formato `AAAA-MM-DD`.
  /// * [goal]: meta semanal (1-7).
  /// * [createdAt]: fecha de creación del hábito.
  /// * [today]: fecha de hoy (se inyecta para poder probar).
  factory HabitStats.compute({
    required Iterable<String> days,
    required int goal,
    required DateTime createdAt,
    required DateTime today,
  }) {
    final todayDate = dateOnly(today);
    final currentWeek = startOfWeek(todayDate);
    final countsByWeek = <DateTime, int>{};
    var total = 0;
    var doneToday = false;

    for (final key in days) {
      final day = parseDayKey(key);
      if (day.isAfter(todayDate)) continue; // Nunca se cuentan días futuros.
      total++;
      if (isSameDay(day, todayDate)) doneToday = true;
      final week = startOfWeek(day);
      countsByWeek[week] = (countsByWeek[week] ?? 0) + 1;
    }

    bool met(DateTime week) => (countsByWeek[week] ?? 0) >= goal;

    // Racha actual: semanas seguidas cumpliendo la meta. La semana en curso
    // suma si ya se cumplió, pero no rompe la racha si todavía no (aún
    // quedan días por delante).
    var current = met(currentWeek) ? 1 : 0;
    var week = addDays(currentWeek, -7);
    while (met(week)) {
      current++;
      week = addDays(week, -7);
    }

    // Mejor racha histórica.
    final metWeeks = countsByWeek.keys.where(met).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final w in metWeeks) {
      run = (previous != null && daysBetween(previous, w) == 7) ? run + 1 : 1;
      if (run > best) best = run;
      previous = w;
    }

    // Porcentaje de semanas cumplidas desde la semana de creación.
    // La semana en curso solo cuenta si ya se cumplió.
    final firstWeek = startOfWeek(createdAt);
    final finishedWeeks = firstWeek.isBefore(currentWeek)
        ? daysBetween(firstWeek, currentWeek) ~/ 7
        : 0;
    var weeksMet = 0;
    for (var i = 0; i < finishedWeeks; i++) {
      if (met(addDays(firstWeek, i * 7))) weeksMet++;
    }
    final currentMet = met(currentWeek);

    return HabitStats._(
      countsByWeek,
      todayDate,
      goal: goal,
      weekCount: countsByWeek[currentWeek] ?? 0,
      doneToday: doneToday,
      currentStreak: current,
      bestStreak: best,
      totalDays: total,
      weeksMet: weeksMet + (currentMet ? 1 : 0),
      weeksConsidered: finishedWeeks + (currentMet ? 1 : 0),
    );
  }

  final int goal;

  /// Días cumplidos en la semana actual.
  final int weekCount;
  final bool doneToday;

  /// Semanas consecutivas cumpliendo la meta (incluye la actual si ya se cumplió).
  final int currentStreak;
  final int bestStreak;

  /// Total de días registrados.
  final int totalDays;
  final int weeksMet;
  final int weeksConsidered;

  final Map<DateTime, int> _countsByWeek;
  final DateTime _today;

  bool get goalMet => weekCount >= goal;

  /// Progreso de la semana entre 0 y 1.
  double get weekProgress => (weekCount / goal).clamp(0, 1).toDouble();

  /// Porcentaje de semanas cumplidas (0-1) o `null` si aún no hay datos.
  double? get completionRate => weeksConsidered == 0 ? null : weeksMet / weeksConsidered;

  /// Las últimas [count] semanas, de la más antigua a la actual.
  List<WeekSummary> lastWeeks(int count) {
    final current = startOfWeek(_today);
    return List.generate(count, (i) {
      final start = addDays(current, -7 * (count - 1 - i));
      return WeekSummary(start: start, count: _countsByWeek[start] ?? 0, goal: goal);
    });
  }
}
