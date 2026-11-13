import 'package:material_ui/material_ui.dart';

@immutable
class FolioPalette extends ThemeExtension<FolioPalette> {
  const FolioPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.accentSecondary,
    required this.contrastSurface,
    required this.contrastInk,
    required this.contrastMuted,
    required this.contrastHairline,
    required this.contrastAccent,
    required this.chartPalette,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color hairline;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color accentSecondary;
  final Color contrastSurface;
  final Color contrastInk;
  final Color contrastMuted;
  final Color contrastHairline;
  final Color contrastAccent;
  final List<Color> chartPalette;

  static FolioPalette fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark() : light();

  static FolioPalette dark() => const FolioPalette(
        canvas: Color(0xFF0D0D0E),
        surface: Color(0xFF141416),
        surfaceAlt: Color(0xFF1B1B1F),
        hairline: Color(0xFF27272A),
        ink: Color(0xFFF8F8F6),
        inkMuted: Color(0xFFA8A59E),
        accent: Color(0xFFC86D51),
        accentSecondary: Color(0xFFD99B52),
        contrastSurface: Color(0xFFF5F3EF),
        contrastInk: Color(0xFF161616),
        contrastMuted: Color(0xFF4B4841),
        contrastHairline: Color(0xFFD6D1C7),
        contrastAccent: Color(0xFFA14225),
        chartPalette: <Color>[
          Color(0xFFC86D51),
          Color(0xFFD99B52),
          Color(0xFF5A8F8C),
          Color(0xFF9387AE),
          Color(0xFFB3544B),
          Color(0xFF7B9B76),
          Color(0xFFA8A59E),
        ],
      );

  static FolioPalette light() => const FolioPalette(
        canvas: Color(0xFFF5F3EF),
        surface: Color(0xFFEDE9E0),
        surfaceAlt: Color(0xFFE3DEC8),
        hairline: Color(0xFFD2CCC0),
        ink: Color(0xFF161616),
        inkMuted: Color(0xFF4E4A42),
        accent: Color(0xFFB34C30),
        accentSecondary: Color(0xFF915E20),
        contrastSurface: Color(0xFF121214),
        contrastInk: Color(0xFFF5F3EF),
        contrastMuted: Color(0xFFB8B3AA),
        contrastHairline: Color(0xFF2A2A2E),
        contrastAccent: Color(0xFFE0896C),
        chartPalette: <Color>[
          Color(0xFFB34C30),
          Color(0xFF915E20),
          Color(0xFF336664),
          Color(0xFF5D5179),
          Color(0xFF8C362E),
          Color(0xFF496945),
          Color(0xFF4E4A42),
        ],
      );

  @override
  FolioPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? hairline,
    Color? ink,
    Color? inkMuted,
    Color? accent,
    Color? accentSecondary,
    Color? contrastSurface,
    Color? contrastInk,
    Color? contrastMuted,
    Color? contrastHairline,
    Color? contrastAccent,
    List<Color>? chartPalette,
  }) {
    return FolioPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      contrastSurface: contrastSurface ?? this.contrastSurface,
      contrastInk: contrastInk ?? this.contrastInk,
      contrastMuted: contrastMuted ?? this.contrastMuted,
      contrastHairline: contrastHairline ?? this.contrastHairline,
      contrastAccent: contrastAccent ?? this.contrastAccent,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  FolioPalette lerp(ThemeExtension<FolioPalette>? other, double t) {
    if (other is! FolioPalette) return this;
    return FolioPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      contrastSurface: Color.lerp(contrastSurface, other.contrastSurface, t)!,
      contrastInk: Color.lerp(contrastInk, other.contrastInk, t)!,
      contrastMuted: Color.lerp(contrastMuted, other.contrastMuted, t)!,
      contrastHairline: Color.lerp(contrastHairline, other.contrastHairline, t)!,
      contrastAccent: Color.lerp(contrastAccent, other.contrastAccent, t)!,
      chartPalette: chartPalette,
    );
  }
}

extension FolioContext on BuildContext {
  FolioPalette get folio {
    final ext = Theme.of(this).extension<FolioPalette>();
    return ext ?? FolioPalette.fromBrightness(Theme.of(this).brightness);
  }

  TextStyle displayStyle({
    double size = 36,
    FontWeight weight = FontWeight.w400,
    double height = 1.05,
    double letterSpacing = -0.02,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'BodoniModa',
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * letterSpacing,
      color: color ?? folio.ink,
    );
  }

  TextStyle monoStyle({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0.08,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color ?? folio.inkMuted,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light, FolioPalette.light());
  static ThemeData dark() => _build(Brightness.dark, FolioPalette.dark());

  static ThemeData _build(Brightness brightness, FolioPalette p) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: const Color(0xFFF8F8F6),
      primaryContainer: p.surfaceAlt,
      onPrimaryContainer: p.ink,
      secondary: p.contrastSurface,
      onSecondary: p.contrastInk,
      secondaryContainer: p.surfaceAlt,
      onSecondaryContainer: p.ink,
      tertiary: p.accentSecondary,
      onTertiary: p.contrastInk,
      error: isDark ? const Color(0xFFE07065) : const Color(0xFFA6281F),
      onError: const Color(0xFFF8F8F6),
      errorContainer: isDark ? const Color(0xFF331815) : const Color(0xFFF6DCD9),
      onErrorContainer: isDark ? const Color(0xFFFBE2DF) : const Color(0xFF5D130D),
      surface: p.canvas,
      onSurface: p.ink,
      surfaceContainerHighest: p.surfaceAlt,
      onSurfaceVariant: p.inkMuted,
      outline: p.hairline,
      outlineVariant: p.hairline,
    );

    const sharpShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)),
    );

    final baseText = (isDark ? Typography.whiteMountainView : Typography.blackMountainView)
        .apply(
      fontFamily: 'Archivo',
      bodyColor: p.ink,
      displayColor: p.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Archivo',
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      focusColor: p.accent.withValues(alpha: 0.18),
      hoverColor: p.accent.withValues(alpha: 0.08),
      extensions: [p],
      textTheme: baseText.copyWith(
        displayLarge: TextStyle(
          fontFamily: 'BodoniModa',
          fontSize: 64,
          height: 0.96,
          letterSpacing: -1.6,
          color: p.ink,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'BodoniModa',
          fontSize: 40,
          height: 1.04,
          letterSpacing: -0.8,
          color: p.ink,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'BodoniModa',
          fontSize: 30,
          height: 1.1,
          letterSpacing: -0.4,
          color: p.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'BodoniModa',
          fontSize: 24,
          height: 1.15,
          color: p.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Archivo',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Archivo',
          fontSize: 16,
          height: 1.55,
          color: p.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Archivo',
          fontSize: 14,
          height: 1.5,
          color: p.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: p.inkMuted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: p.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: sharpShape,
        side: BorderSide(color: p.hairline),
        backgroundColor: p.surface,
        selectedColor: p.contrastSurface,
        checkmarkColor: p.contrastInk,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: isSelected ? p.contrastInk : p.ink,
          );
        }),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: p.contrastInk,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.contrastSurface,
          foregroundColor: p.contrastInk,
          shape: sharpShape,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: const TextStyle(
            fontFamily: 'Archivo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: p.accent, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.hairline),
          shape: sharpShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(
            fontFamily: 'Archivo',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: p.accent, width: 1.8);
            }
            return BorderSide(color: p.hairline);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          shape: sharpShape,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Archivo',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: p.accent, width: 1.5);
            }
            return BorderSide.none;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: sharpShape).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: p.accent, width: 1.8);
            }
            return BorderSide.none;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.inkMuted, fontSize: 14),
        hintStyle: TextStyle(color: p.inkMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: p.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.35),
        selectionHandleColor: p.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(1),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return p.accent;
          return p.hairline;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.canvas,
        elevation: 0,
        indicatorColor: p.surfaceAlt,
        indicatorShape: sharpShape,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Archivo', fontSize: 11, color: p.inkMuted),
        ),
      ),
    );
  }
}
