import 'package:drift/drift.dart';

import '../core/dates.dart';
import 'database.dart';

/// Un hábito junto con todos los días en que se cumplió.
class HabitWithDays {
  HabitWithDays(this.habit, this.days);

  final Habit habit;

  /// Días cumplidos en formato `AAAA-MM-DD`.
  final Set<String> days;
}

/// Se lanza al intentar guardar un hábito con un nombre que ya existe.
class DuplicateHabitNameException implements Exception {
  const DuplicateHabitNameException(this.name);
  final String name;

  @override
  String toString() => 'Ya existe un hábito llamado "$name"';
}

/// Se lanza al intentar registrar un día que todavía no llega.
class FutureDayException implements Exception {
  const FutureDayException();
}

/// Todas las operaciones sobre hábitos y registros diarios.
///
/// La interfaz nunca habla con SQL directamente: usa este repositorio.
/// Los métodos `watch...` devuelven streams que emiten de nuevo cada vez que
/// cambian las tablas involucradas, así la pantalla se actualiza sola.
class HabitRepository {
  HabitRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Normaliza un nombre para detectar duplicados: minúsculas, sin acentos
  /// (pero conservando la ñ) y sin espacios repetidos.
  static String normalizeName(String name) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
    };
    final lower = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return lower.split('').map((c) => accents[c] ?? c).join();
  }

  /// Limpia espacios sobrantes del nombre que se muestra.
  static String cleanName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  /// Todos los hábitos (en orden de creación) con sus días cumplidos.
  /// Es una sola consulta con LEFT JOIN.
  Stream<List<HabitWithDays>> watchAll() {
    final query = _db.select(_db.habits).join([
      leftOuterJoin(_db.checkIns, _db.checkIns.habitId.equalsExp(_db.habits.id)),
    ])..orderBy([OrderingTerm.asc(_db.habits.id)]);

    return query.watch().map((rows) {
      final byId = <int, HabitWithDays>{};
      for (final row in rows) {
        final habit = row.readTable(_db.habits);
        final entry = byId.putIfAbsent(habit.id, () => HabitWithDays(habit, {}));
        final checkIn = row.readTableOrNull(_db.checkIns);
        if (checkIn != null) entry.days.add(checkIn.day);
      }
      return byId.values.toList();
    });
  }

  /// Un hábito con sus días; emite `null` si se borra. Reacciona a cambios
  /// tanto del hábito como de sus registros.
  Stream<HabitWithDays?> watchOne(int id) {
    final query = _db.select(_db.habits).join([
      leftOuterJoin(_db.checkIns, _db.checkIns.habitId.equalsExp(_db.habits.id)),
    ])..where(_db.habits.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      final habit = rows.first.readTable(_db.habits);
      final days = <String>{
        for (final row in rows)
          if (row.readTableOrNull(_db.checkIns) case final checkIn?) checkIn.day,
      };
      return HabitWithDays(habit, days);
    });
  }

  Future<bool> isNameTaken(String name, {int? exceptId}) async {
    final key = normalizeName(name);
    final query = _db.select(_db.habits)..where((h) => h.nameKey.equals(key));
    if (exceptId != null) query.where((h) => h.id.equals(exceptId).not());
    return (await query.get()).isNotEmpty;
  }

  Future<int> countHabits() => _db.habits.count().getSingle();

  Future<int> countCheckIns() => _db.checkIns.count().getSingle();

  // ---------------------------------------------------------------------------
  // Escritura
  // ---------------------------------------------------------------------------

  Future<int> create({
    required String name,
    required int weeklyGoal,
    int colorIndex = 0,
    String icon = 'spa',
    DateTime? createdAt,
  }) {
    return _db.transaction(() async {
      if (await isNameTaken(name)) throw DuplicateHabitNameException(cleanName(name));
      return _db
          .into(_db.habits)
          .insert(
            HabitsCompanion.insert(
              name: cleanName(name),
              nameKey: normalizeName(name),
              weeklyGoal: weeklyGoal,
              colorIndex: Value(colorIndex),
              icon: Value(icon),
              createdAt: Value.absentIfNull(createdAt),
            ),
          );
    });
  }

  Future<void> update({
    required int id,
    required String name,
    required int weeklyGoal,
    required int colorIndex,
    required String icon,
  }) {
    return _db.transaction(() async {
      if (await isNameTaken(name, exceptId: id)) {
        throw DuplicateHabitNameException(cleanName(name));
      }
      await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          name: Value(cleanName(name)),
          nameKey: Value(normalizeName(name)),
          weeklyGoal: Value(weeklyGoal),
          colorIndex: Value(colorIndex),
          icon: Value(icon),
        ),
      );
    });
  }

  /// Borra el hábito; sus registros se van por ON DELETE CASCADE.
  Future<void> delete(int id) => (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();

  /// Marca o desmarca un día. Devuelve `true` si el día quedó marcado.
  Future<bool> toggleDay(int habitId, DateTime day) async {
    _ensureNotFuture(day);
    return _db.transaction(() async {
      final key = dayKey(day);
      final deleted = await (_db.delete(
        _db.checkIns,
      )..where((c) => c.habitId.equals(habitId) & c.day.equals(key))).go();
      if (deleted > 0) return false;
      await _db.into(_db.checkIns).insert(CheckInsCompanion.insert(habitId: habitId, day: key));
      return true;
    });
  }

  /// Fija el estado de un día (usado por "Deshacer").
  Future<void> setDay(int habitId, DateTime day, {required bool done}) async {
    _ensureNotFuture(day);
    final key = dayKey(day);
    if (done) {
      await _db
          .into(_db.checkIns)
          .insert(
            CheckInsCompanion.insert(habitId: habitId, day: key),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(
        _db.checkIns,
      )..where((c) => c.habitId.equals(habitId) & c.day.equals(key))).go();
    }
  }

  /// Borra todos los hábitos y registros.
  Future<void> deleteAll() => _db.transaction(() async {
    await _db.delete(_db.checkIns).go();
    await _db.delete(_db.habits).go();
  });

  /// Crea hábitos de ejemplo con historial, útil para presentar la app.
  Future<void> seedDemoData() {
    final today = dateOnly(_clock());
    return _db.transaction(() async {
      final demo = [
        (name: 'Hacer ejercicio', goal: 5, color: 1, icon: 'fitness', pattern: [0, 1, 2, 4, 5]),
        (name: 'Leer 20 min', goal: 7, color: 0, icon: 'book', pattern: [0, 1, 2, 3, 4, 5, 6]),
        (name: 'Meditar', goal: 3, color: 6, icon: 'spa', pattern: [0, 2, 4]),
        (name: 'Tomar 2 L de agua', goal: 6, color: 2, icon: 'water', pattern: [0, 1, 3, 4, 5, 6]),
      ];
      const weeks = 12;
      for (final (index, h) in demo.indexed) {
        if (await isNameTaken(h.name)) continue;
        final id = await create(
          name: h.name,
          weeklyGoal: h.goal,
          colorIndex: h.color,
          icon: h.icon,
          createdAt: addDays(startOfWeek(today), -7 * weeks),
        );
        for (var w = weeks; w >= 0; w--) {
          final monday = addDays(startOfWeek(today), -7 * w);
          // Algunas semanas con huecos para que las estadísticas sean variadas.
          final skip = (w + index) % 4 == 3 ? 2 : 0;
          for (final (i, offset) in h.pattern.indexed) {
            if (i < skip) continue;
            final day = addDays(monday, offset);
            if (day.isAfter(today)) continue;
            await _db
                .into(_db.checkIns)
                .insert(
                  CheckInsCompanion.insert(habitId: id, day: dayKey(day)),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }
    });
  }

  void _ensureNotFuture(DateTime day) {
    if (dateOnly(day).isAfter(dateOnly(_clock()))) throw const FutureDayException();
  }
}
