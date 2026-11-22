import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:mis_habitos/core/pin_hasher.dart';
import 'package:mis_habitos/data/database.dart';
import 'package:mis_habitos/data/habit_repository.dart';
import 'package:mis_habitos/data/settings_repository.dart';

void main() {
  late AppDatabase db;
  late HabitRepository habits;
  late SettingsRepository settings;
  var now = DateTime(2026, 11, 22, 10);

  setUp(() {
    now = DateTime(2026, 11, 22, 10);
    db = AppDatabase(NativeDatabase.memory());
    habits = HabitRepository(db, clock: () => now);
    settings = SettingsRepository(
      db,
      clock: () => now,
      iterations: 1000,
      hashFunction: (pin, salt, iterations) async => PinHasher.hash(pin, salt, iterations),
    );
  });

  tearDown(() => db.close());

  group('hábitos', () {
    test('crear y leer con sus días', () async {
      final id = await habits.create(
        name: '  Hacer   ejercicio ',
        weeklyGoal: 5,
        colorIndex: 1,
        icon: 'fitness',
      );
      await habits.toggleDay(id, DateTime(2026, 11, 20));
      await habits.toggleDay(id, DateTime(2026, 11, 22));

      final all = await habits.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.habit.name, 'Hacer ejercicio');
      expect(all.single.habit.weeklyGoal, 5);
      expect(all.single.days, {'2026-11-20', '2026-11-22'});
    });

    test('no permite nombres duplicados (ignora mayúsculas, acentos y espacios)', () async {
      await habits.create(name: 'Meditar', weeklyGoal: 3);
      expect(
        () => habits.create(name: '  MEDÍTAR ', weeklyGoal: 2),
        throwsA(isA<DuplicateHabitNameException>()),
      );
      // La ñ sí cuenta: "Año" y "Ano" son nombres distintos.
      await habits.create(name: 'Año nuevo', weeklyGoal: 1);
      await habits.create(name: 'Ano nuevo', weeklyGoal: 1);
    });

    test('la base de datos rechaza una meta fuera de 1 a 7 (CHECK)', () async {
      expect(
        () => db
            .into(db.habits)
            .insert(HabitsCompanion.insert(name: 'Meditar', nameKey: 'meditar', weeklyGoal: 9)),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db
            .into(db.habits)
            .insert(HabitsCompanion.insert(name: 'Leer', nameKey: 'leer', weeklyGoal: 0)),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'la base de datos rechaza nombres vacíos y días mal formados aunque se use SQL directo',
      () async {
        expect(
          () => db.customStatement(
            "INSERT INTO habits (name, name_key, weekly_goal) VALUES ('', 'x', 3)",
          ),
          throwsA(isA<SqliteException>()),
        );
        final id = await habits.create(name: 'Leer', weeklyGoal: 7);
        expect(
          () =>
              db.customStatement("INSERT INTO check_ins (habit_id, day) VALUES ($id, '2026-1-5')"),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('un día solo puede registrarse una vez (llave primaria compuesta)', () async {
      final id = await habits.create(name: 'Leer', weeklyGoal: 7);
      await db.into(db.checkIns).insert(CheckInsCompanion.insert(habitId: id, day: '2026-11-22'));
      expect(
        () => db.into(db.checkIns).insert(CheckInsCompanion.insert(habitId: id, day: '2026-11-22')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('toggleDay marca y desmarca', () async {
      final id = await habits.create(name: 'Leer', weeklyGoal: 7);
      expect(await habits.toggleDay(id, now), isTrue);
      expect(await habits.toggleDay(id, now), isFalse);
      expect(await habits.countCheckIns(), 0);
    });

    test('no se pueden registrar días futuros', () async {
      final id = await habits.create(name: 'Leer', weeklyGoal: 7);
      expect(
        () => habits.toggleDay(id, DateTime(2026, 11, 23)),
        throwsA(isA<FutureDayException>()),
      );
    });

    test('borrar un hábito borra sus registros (ON DELETE CASCADE)', () async {
      final id = await habits.create(name: 'Leer', weeklyGoal: 7);
      await habits.toggleDay(id, now);
      await habits.toggleDay(id, DateTime(2026, 11, 21));
      await habits.delete(id);
      expect(await habits.countHabits(), 0);
      expect(await habits.countCheckIns(), 0);
    });

    test('la llave foránea impide registros de hábitos inexistentes', () async {
      expect(
        () =>
            db.into(db.checkIns).insert(CheckInsCompanion.insert(habitId: 999, day: '2026-11-22')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('editar respeta la unicidad pero permite conservar el propio nombre', () async {
      final a = await habits.create(name: 'Leer', weeklyGoal: 7);
      await habits.create(name: 'Correr', weeklyGoal: 3);
      await habits.update(id: a, name: 'leer', weeklyGoal: 5, colorIndex: 2, icon: 'book');
      expect(
        () => habits.update(id: a, name: 'Correr', weeklyGoal: 5, colorIndex: 2, icon: 'book'),
        throwsA(isA<DuplicateHabitNameException>()),
      );
    });

    test('watchAll emite de nuevo al registrar un día', () async {
      final id = await habits.create(name: 'Leer', weeklyGoal: 7);
      final stream = habits.watchAll();
      expectLater(stream.map((list) => list.single.days.length), emitsInOrder([0, 1]));
      await Future<void>.delayed(Duration.zero);
      await habits.toggleDay(id, now);
    });

    test('datos de ejemplo', () async {
      await habits.seedDemoData();
      expect(await habits.countHabits(), 4);
      expect(await habits.countCheckIns(), greaterThan(100));
      // Ejecutarlo de nuevo no duplica.
      await habits.seedDemoData();
      expect(await habits.countHabits(), 4);
    });
  });

  group('PIN y ajustes', () {
    test('el PIN se guarda como hash, nunca en texto plano', () async {
      expect(await settings.hasPin(), isFalse);
      await settings.setPin('4821');
      expect(await settings.hasPin(), isTrue);
      final rows = await db.select(db.appSettings).get();
      expect(rows.any((r) => r.value.contains('4821')), isFalse);
    });

    test('verificar PIN correcto e incorrecto', () async {
      await settings.setPin('4821');
      expect(await settings.verifyPin('4821'), isA<PinOk>());
      final wrong = await settings.verifyPin('0000');
      expect(wrong, isA<PinWrong>());
      expect((wrong as PinWrong).attemptsLeft, SettingsRepository.maxAttempts - 1);
    });

    test('se bloquea tras 5 intentos y se libera a los 30 s', () async {
      await settings.setPin('4821');
      for (var i = 0; i < SettingsRepository.maxAttempts - 1; i++) {
        expect(await settings.verifyPin('0000'), isA<PinWrong>());
      }
      expect(await settings.verifyPin('0000'), isA<PinLocked>());
      // Ni el PIN correcto entra durante el bloqueo.
      expect(await settings.verifyPin('4821'), isA<PinLocked>());

      now = now.add(SettingsRepository.lockDuration + const Duration(seconds: 1));
      expect(await settings.remainingLock(), isNull);
      expect(await settings.verifyPin('4821'), isA<PinOk>());
    });

    test('un acierto reinicia el contador de intentos', () async {
      await settings.setPin('4821');
      await settings.verifyPin('0000');
      await settings.verifyPin('0000');
      await settings.verifyPin('4821');
      final wrong = await settings.verifyPin('0000') as PinWrong;
      expect(wrong.attemptsLeft, SettingsRepository.maxAttempts - 1);
    });

    test('rechaza PIN que no sean 4 dígitos', () {
      expect(() => settings.setPin('12a4'), throwsArgumentError);
      expect(() => settings.setPin('123'), throwsArgumentError);
    });

    test('el tema se guarda', () async {
      expect(await settings.watchThemeMode().first, ThemeMode.system);
      await settings.setThemeMode(ThemeMode.dark);
      expect(await settings.watchThemeMode().first, ThemeMode.dark);
    });
  });
}
