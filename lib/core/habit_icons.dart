import 'package:material_ui/material_ui.dart';

/// Íconos disponibles para los hábitos. En la base de datos se guarda la
/// clave (texto), no el código del ícono, para que el árbol de íconos de
/// Flutter pueda optimizarse y los datos no dependan de la versión.
const habitIcons = <String, IconData>{
  'spa': Icons.self_improvement_rounded,
  'fitness': Icons.fitness_center_rounded,
  'book': Icons.menu_book_rounded,
  'water': Icons.water_drop_rounded,
  'run': Icons.directions_run_rounded,
  'walk': Icons.directions_walk_rounded,
  'bike': Icons.directions_bike_rounded,
  'bed': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded,
  'music': Icons.music_note_rounded,
  'code': Icons.code_rounded,
  'brush': Icons.brush_rounded,
  'language': Icons.translate_rounded,
  'savings': Icons.savings_rounded,
  'heart': Icons.favorite_rounded,
  'leaf': Icons.eco_rounded,
  'study': Icons.school_rounded,
  'phone_off': Icons.phonelink_erase_rounded,
};

IconData habitIcon(String key) => habitIcons[key] ?? Icons.star_rounded;
