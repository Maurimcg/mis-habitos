/// Utilidades de fechas. Todo se trabaja con días locales (sin hora) y las
/// semanas empiezan en lunes.
///
/// Para sumar días se usa `DateTime(año, mes, día + n)` en lugar de
/// `Duration(days: n)`: así los cambios de horario de verano no mueven
/// la fecha.
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Lunes de la semana a la que pertenece [d].
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), -(d.weekday - DateTime.monday));

/// Los 7 días (lunes a domingo) de la semana de [d].
List<DateTime> daysOfWeek(DateTime d) {
  final monday = startOfWeek(d);
  return List.generate(7, (i) => addDays(monday, i));
}

/// Clave `AAAA-MM-DD` con la que se guardan los días en la base de datos.
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDayKey(String key) => DateTime(
  int.parse(key.substring(0, 4)),
  int.parse(key.substring(5, 7)),
  int.parse(key.substring(8, 10)),
);

/// Días completos entre dos fechas, sin depender del horario de verano.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Iniciales de los días en español, de lunes a domingo.
const weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

String _two(int n) => n.toString().padLeft(2, '0');
