import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mis_habitos/app.dart';
import 'package:mis_habitos/core/pin_hasher.dart';
import 'package:mis_habitos/core/theme.dart';
import 'package:mis_habitos/data/database.dart';
import 'package:mis_habitos/data/habit_repository.dart';
import 'package:mis_habitos/data/settings_repository.dart';
import 'package:mis_habitos/ui/app_scope.dart';
import 'package:mis_habitos/ui/screens/habit_form_screen.dart';

void main() {
  late AppDatabase db;
  late HabitRepository habits;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    habits = HabitRepository(db);
    settings = SettingsRepository(
      db,
      iterations: 10,
      hashFunction: (pin, salt, iterations) async => PinHasher.hash(pin, salt, iterations),
    );
  });

  /// Desmonta los widgets antes de cerrar la base para que drift cierre sus
  /// streams sin dejar timers pendientes.
  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.bySemanticsLabel(digit).last);
      await tester.pump();
    }
    // Hash + animaciones.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  testWidgets('primer uso: crear PIN, entrar y ver estado vacío; PIN incorrecto al bloquear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MisHabitosApp(habits: habits, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu PIN'), findsOneWidget);
    await typePin(tester, '2580');
    expect(find.text('Confirma tu PIN'), findsOneWidget);

    // Confirmación distinta → vuelve a pedirlo.
    await typePin(tester, '1111');
    expect(find.textContaining('no coinciden'), findsOneWidget);

    await typePin(tester, '2580');
    await typePin(tester, '2580');
    expect(find.text('Empieza con un hábito'), findsOneWidget);

    // Bloquear y equivocarse.
    await tester.tap(find.byTooltip('Bloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu PIN para continuar'), findsOneWidget);
    await typePin(tester, '0000');
    expect(find.textContaining('PIN incorrecto'), findsOneWidget);

    await typePin(tester, '2580');
    expect(find.text('Empieza con un hábito'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('formulario: valida la meta (1 a 7) y guarda en la base de datos', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        habits: habits,
        settings: settings,
        lockNow: () {},
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const HabitFormScreen())),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo hábito'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Meditar');
    await tester.enterText(find.byKey(const Key('goalField')), '9');
    await tester.pump();
    expect(find.text('Debe estar entre 1 y 7'), findsOneWidget);

    // Guardar con error no crea nada.
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(await habits.countHabits(), 0);

    await tester.enterText(find.byKey(const Key('goalField')), '3');
    await tester.pump();
    expect(find.text('Debe estar entre 1 y 7'), findsNothing);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.habits).getSingle();
    expect(saved.name, 'Meditar');
    expect(saved.weeklyGoal, 3);
    expect(find.text('«Meditar» agregado'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('formulario: avisa si el nombre ya existe', (tester) async {
    await habits.create(name: 'Leer 20 min', weeklyGoal: 7);
    await tester.pumpWidget(
      AppScope(
        habits: habits,
        settings: settings,
        lockNow: () {},
        child: const MaterialApp(home: HabitFormScreen()),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'leer 20 MIN');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya tienes un hábito con ese nombre'), findsOneWidget);
    expect(await habits.countHabits(), 1);

    await cleanUp(tester);
  });
}
