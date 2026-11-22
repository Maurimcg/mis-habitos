import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/habit_repository.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';

  // Una sola instancia de la base de datos para toda la app.
  final db = AppDatabase();

  runApp(MisHabitosApp(habits: HabitRepository(db), settings: SettingsRepository(db)));
}
