import 'package:flutter_test/flutter_test.dart';
import 'package:mis_habitos/core/dates.dart';
import 'package:mis_habitos/domain/habit_stats.dart';

void main() {
  group('fechas', () {
    test('la semana empieza en lunes', () {
      // Domingo 22 de noviembre de 2026 → lunes 16.
      expect(startOfWeek(DateTime(2026, 11, 22)), DateTime(2026, 11, 16));
      expect(startOfWeek(DateTime(2026, 11, 16, 23, 59)), DateTime(2026, 11, 16));
      // Cruce de mes y de año.
      expect(startOfWeek(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });

    test('dayKey y parseDayKey son inversos', () {
      final day = DateTime(2026, 3, 9);
      expect(dayKey(day), '2026-03-09');
      expect(parseDayKey('2026-03-09'), day);
    });

    test('daysBetween no se afecta por horario de verano', () {
      // Cambio de horario en EE. UU. (8 mar 2026) y Europa (29 mar 2026).
      expect(daysBetween(DateTime(2026, 3, 2), DateTime(2026, 3, 9)), 7);
      expect(daysBetween(DateTime(2026, 3, 23), DateTime(2026, 3, 30)), 7);
    });
  });

  group('HabitStats', () {
    final today = DateTime(2026, 11, 22); // domingo
    final created = DateTime(2026, 10, 1);

    // Genera los días de una semana a partir de su lunes.
    List<String> week(DateTime monday, List<int> offsets) => [
      for (final o in offsets) dayKey(addDays(monday, o)),
    ];

    final thisWeek = DateTime(2026, 11, 16);

    test('cuenta los días de la semana actual y detecta la meta', () {
      final stats = HabitStats.compute(
        days: week(thisWeek, [0, 2, 4]),
        goal: 5,
        createdAt: created,
        today: today,
      );
      expect(stats.weekCount, 3);
      expect(stats.goalMet, isFalse);
      expect(stats.weekProgress, closeTo(0.6, 1e-9));
      expect(stats.doneToday, isFalse);
    });

    test('ignora días futuros', () {
      final stats = HabitStats.compute(
        days: [dayKey(today), dayKey(addDays(today, 1))],
        goal: 1,
        createdAt: created,
        today: today,
      );
      expect(stats.totalDays, 1);
      expect(stats.doneToday, isTrue);
    });

    test('la semana en curso no rompe la racha si aún no se cumple', () {
      final days = [
        ...week(addDays(thisWeek, -14), [0, 1, 2]),
        ...week(addDays(thisWeek, -7), [0, 1, 2]),
        ...week(thisWeek, [0]), // va 1 de 3
      ];
      final stats = HabitStats.compute(days: days, goal: 3, createdAt: created, today: today);
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 2);
    });

    test('la semana actual suma a la racha cuando ya se cumplió', () {
      final days = [
        ...week(addDays(thisWeek, -7), [0, 1]),
        ...week(thisWeek, [0, 1]),
      ];
      final stats = HabitStats.compute(days: days, goal: 2, createdAt: created, today: today);
      expect(stats.currentStreak, 2);
    });

    test('mejor racha considera semanas consecutivas del pasado', () {
      final days = [
        ...week(DateTime(2026, 10, 5), [0]),
        ...week(DateTime(2026, 10, 12), [0]),
        ...week(DateTime(2026, 10, 19), [0]),
        // hueco la semana del 26 de octubre
        ...week(DateTime(2026, 11, 2), [0]),
      ];
      final stats = HabitStats.compute(days: days, goal: 1, createdAt: created, today: today);
      expect(stats.bestStreak, 3);
      expect(stats.currentStreak, 0); // la semana pasada (9 nov) no se cumplió
    });

    test('porcentaje de semanas cumplidas desde la creación', () {
      // Creado el lunes 2 de noviembre: semanas terminadas 2 y 9 de nov.
      final days = [
        ...week(DateTime(2026, 11, 2), [0, 1]),
        ...week(DateTime(2026, 11, 9), [0]),
      ];
      final stats = HabitStats.compute(
        days: days,
        goal: 2,
        createdAt: DateTime(2026, 11, 2, 10),
        today: today,
      );
      expect(stats.weeksMet, 1);
      expect(stats.weeksConsidered, 2);
      expect(stats.completionRate, 0.5);
    });

    test('sin semanas completas el porcentaje es null', () {
      final stats = HabitStats.compute(days: const [], goal: 3, createdAt: today, today: today);
      expect(stats.completionRate, isNull);
    });

    test('lastWeeks devuelve las semanas en orden, terminando en la actual', () {
      final stats = HabitStats.compute(
        days: [
          ...week(thisWeek, [0, 1]),
          ...week(addDays(thisWeek, -7), [3]),
        ],
        goal: 2,
        createdAt: created,
        today: today,
      );
      final weeks = stats.lastWeeks(3);
      expect(weeks.map((w) => w.start), [addDays(thisWeek, -14), addDays(thisWeek, -7), thisWeek]);
      expect(weeks.map((w) => w.count), [0, 1, 2]);
      expect(weeks.last.goalMet, isTrue);
    });
  });
}
