import 'package:material_ui/material_ui.dart';

/// Colores propios de la app que Material no trae: paleta de hábitos y
/// color de "meta cumplida". Cambian entre modo claro y oscuro.
@immutable
class HabitColors extends ThemeExtension<HabitColors> {
  const HabitColors({required this.palette, required this.onPalette, required this.success});

  /// 8 colores de identidad para los hábitos. Es una paleta categórica
  /// validada para daltonismo (cada par vecino se distingue), con tonos
  /// distintos para claro y oscuro.
  final List<Color> palette;

  /// Color de íconos/texto encima de cada color de la paleta.
  final List<Color> onPalette;

  /// Verde para "meta cumplida".
  final Color success;

  static const light = HabitColors(
    palette: [
      Color(0xFF2A78D6), // azul
      Color(0xFFEB6834), // naranja
      Color(0xFF1BAF7A), // aqua
      Color(0xFFEDA100), // amarillo
      Color(0xFFE87BA4), // rosa
      Color(0xFF008300), // verde
      Color(0xFF6250D6), // violeta
      Color(0xFFE34948), // rojo
    ],
    onPalette: [
      Colors.white,
      Colors.white,
      Colors.white,
      Color(0xFF0B0B0B),
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    success: Color(0xFF006300),
  );

  static const dark = HabitColors(
    palette: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF0CA30C),
      Color(0xFF9085E9),
      Color(0xFFE66767),
    ],
    onPalette: [
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    success: Color(0xFF0CA30C),
  );

  static const names = ['Azul', 'Naranja', 'Aqua', 'Amarillo', 'Rosa', 'Verde', 'Violeta', 'Rojo'];

  Color color(int index) => palette[index.clamp(0, palette.length - 1)];
  Color onColor(int index) => onPalette[index.clamp(0, onPalette.length - 1)];

  static HabitColors of(BuildContext context) =>
      Theme.of(context).extension<HabitColors>() ?? light;

  @override
  HabitColors copyWith({List<Color>? palette, List<Color>? onPalette, Color? success}) =>
      HabitColors(
        palette: palette ?? this.palette,
        onPalette: onPalette ?? this.onPalette,
        success: success ?? this.success,
      );

  @override
  HabitColors lerp(HabitColors? other, double t) {
    if (other == null) return this;
    return HabitColors(
      palette: [
        for (var i = 0; i < palette.length; i++) Color.lerp(palette[i], other.palette[i], t)!,
      ],
      onPalette: t < 0.5 ? onPalette : other.onPalette,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const fontFamily = 'PlusJakartaSans';
  static const brand = Color(0xFF4F46E5);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          surface: isDark ? const Color(0xFF111116) : const Color(0xFFF5F5FA),
          surfaceContainerLowest: isDark ? const Color(0xFF0B0B0F) : Colors.white,
          surfaceContainerLow: isDark ? const Color(0xFF1A1A21) : Colors.white,
          surfaceContainer: isDark ? const Color(0xFF202029) : const Color(0xFFF0F0F6),
          surfaceContainerHigh: isDark ? const Color(0xFF282832) : const Color(0xFFE9E9F1),
          surfaceContainerHighest: isDark ? const Color(0xFF31313C) : const Color(0xFFE2E2EB),
          outlineVariant: isDark ? const Color(0xFF2F2F3A) : const Color(0xFFE4E4EC),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final radius16 = BorderRadius.circular(16);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [isDark ? HabitColors.dark : HabitColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius16),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: text.titleMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.titleSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
