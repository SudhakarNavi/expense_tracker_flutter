import 'package:flutter/material.dart';

/// Semantic colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color income;
  final Color expense;
  final Color warning;
  final Color incomeContainer;
  final Color expenseContainer;
  final Color warningContainer;
  final Color hero;
  final Color heroAccent;
  final Color onHero;

  const AppColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.incomeContainer,
    required this.expenseContainer,
    required this.warningContainer,
    required this.hero,
    required this.heroAccent,
    required this.onHero,
  });

  static const light = AppColors(
    income: Color(0xFF15803D),
    expense: Color(0xFFB91C1C),
    warning: Color(0xFFB45309),
    incomeContainer: Color(0xFFDCFCE7),
    expenseContainer: Color(0xFFFEE2E2),
    warningContainer: Color(0xFFFEF3C7),
    hero: Color(0xFF0E5253),
    heroAccent: Color(0xFF2E7D7D),
    onHero: Colors.white,
  );

  static const dark = AppColors(
    income: Color(0xFF4ADE80),
    expense: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    incomeContainer: Color(0xFF14532D),
    expenseContainer: Color(0xFF7F1D1D),
    warningContainer: Color(0xFF78350F),
    hero: Color(0xFF123F40),
    heroAccent: Color(0xFF1D5C5C),
    onHero: Colors.white,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      income: l(income, other.income),
      expense: l(expense, other.expense),
      warning: l(warning, other.warning),
      incomeContainer: l(incomeContainer, other.incomeContainer),
      expenseContainer: l(expenseContainer, other.expenseContainer),
      warningContainer: l(warningContainer, other.warningContainer),
      hero: l(hero, other.hero),
      heroAccent: l(heroAccent, other.heroAccent),
      onHero: l(onHero, other.onHero),
    );
  }
}

/// Tabular figures keep columns of amounts aligned.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF0E5253);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = isDark
        ? base
        : base.copyWith(
            surface: const Color(0xFFF6F8FA),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Colors.white,
          );

    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [isDark ? AppColors.dark : AppColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }
}
