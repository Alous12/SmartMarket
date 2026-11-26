import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Paleta de los mockups de SmartMarket.
  static const green = Color(0xFF2F5A27);
  static const lime = Color(0xFFA8DD84);
  static const background = Color(0xFFF4F6F0);
  static const tint = Color(0xFFEEF5E6);
  static const track = Color(0xFFE6E9E2);
  static const border = Color(0xFFE8EBE4);
  static const ink = Color(0xFF1C1F1A);
  static const muted = Color(0xFF6B7066);

  /// Cabeceras oscuras del modo admin y banner de edición.
  static const night = Color(0xFF1C1F1A);

  /// Texto secundario sobre [night].
  static const onNightMuted = Color(0xFFC6D2BD);

  /// Agotado, quitar y errores.
  static const danger = Color(0xFFA6261A);
  static const dangerTint = Color(0xFFFBE7E5);

  /// Stock bajo y sustitutos.
  static const warning = Color(0xFF92400E);
  static const warningTint = Color(0xFFFDF1DC);

  // Radios: chips, botones, tarjetas y hojas inferiores.
  static const radiusS = 12.0;
  static const radiusM = 16.0;
  static const radiusL = 20.0;
  static const radiusXL = 28.0;

  /// Separaciones en múltiplos de 4.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;

  /// Alto de los botones principales.
  static const buttonHeight = 56.0;

  /// Duraciones de las animaciones.
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 300);

  static const cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// La duración [value], o cero si el sistema pide quitar animaciones.
  static Duration motion(BuildContext context, Duration value) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : value;

  static const _textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.15,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.2,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: ink),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: ink,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: muted,
    ),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: border),
  );

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      secondary: lime,
      surface: Colors.white,
      onSurface: ink,
      error: danger,
    ),
    scaffoldBackgroundColor: background,
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusL),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _fieldBorder,
      enabledBorder: _fieldBorder,
      focusedBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: green, width: 2),
      ),
      errorBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: danger, width: 2),
      ),
      labelStyle: const TextStyle(color: muted),
      floatingLabelStyle: const TextStyle(
        color: green,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: muted),
      prefixIconColor: muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: ink,
        disabledBackgroundColor: track,
        disabledForegroundColor: muted,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lime,
      foregroundColor: ink,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusL),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: night,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusS),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusS),
      ),
      labelStyle: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? lime : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? green : track,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : const Color(0xFFDDE1D8),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? green : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: Color(0xFFCFD7C9), width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: lime,
      surfaceTintColor: Colors.transparent,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected) ? ink : muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
    ),
  );
}
