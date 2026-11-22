import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Hábitos que la persona quiere cumplir cierto número de días por semana.
///
/// Las reglas de negocio importantes también viven en la base de datos
/// (CHECK y UNIQUE), así un error de la interfaz no puede guardar datos
/// inválidos.
@DataClassName('Habit')
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nombre visible, p. ej. "Hacer ejercicio".
  // ignore: recursive_getters
  TextColumn get name =>
      text().withLength(min: 1, max: 40).check(name.length.isBetweenValues(1, 40))();

  /// Nombre normalizado (minúsculas, sin acentos ni espacios repetidos).
  /// Es UNIQUE para impedir duplicados como "Meditar" y "  meditar".
  TextColumn get nameKey => text().unique()();

  /// Días por semana que se quieren cumplir: de 1 a 7.
  // ignore: recursive_getters (patrón de drift para CHECK sobre la columna)
  IntColumn get weeklyGoal => integer().check(weeklyGoal.isBetweenValues(1, 7))();

  /// Posición en la paleta de colores (0-7). Se guarda el índice y no el
  /// color en sí, para elegir el tono adecuado en modo claro u oscuro.
  IntColumn get colorIndex => integer()
      .withDefault(const Constant(0))
      // ignore: recursive_getters
      .check(colorIndex.isBetweenValues(0, 7))();

  /// Clave del ícono (ver `core/habit_icons.dart`).
  TextColumn get icon => text().withDefault(const Constant('spa'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Un registro por cada día en que se cumplió un hábito.
///
/// La clave primaria compuesta (habit_id, day) garantiza que un hábito no
/// pueda marcarse dos veces el mismo día. Al borrar un hábito se borran sus
/// registros (ON DELETE CASCADE).
@DataClassName('CheckIn')
@TableIndex(name: 'check_ins_day', columns: {#day})
class CheckIns extends Table {
  IntColumn get habitId => integer().references(Habits, #id, onDelete: KeyAction.cascade)();

  /// Fecha local en formato ISO `AAAA-MM-DD`. Se ordena correctamente como
  /// texto, se lee fácil en cualquier visor de SQLite y no depende de la
  /// zona horaria.
  // ignore: recursive_getters
  TextColumn get day => text().withLength(min: 10, max: 10).check(day.length.equals(10))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {habitId, day};
}

/// Preferencias clave-valor: hash del PIN, tema, intentos fallidos...
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Habits, CheckIns, AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Sin argumentos abre el archivo `mis_habitos.sqlite` en la carpeta
  /// privada de la app (Application Support), que el usuario no ve ni
  /// comparte. En las pruebas se pasa una base en memoria.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static QueryExecutor _openDefault() => driftDatabase(
    name: 'mis_habitos',
    native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // SQLite trae las llaves foráneas apagadas por defecto.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
