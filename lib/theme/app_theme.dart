import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF070710);
  static const Color s1 = Color(0xFF0E0E1C);
  static const Color s2 = Color(0xFF15152A);
  static const Color s3 = Color(0xFF1C1C35);
  static const Color red = Color(0xFFFF2D55);
  static const Color orange = Color(0xFFFF9500);
  static const Color green = Color(0xFF30D158);
  static const Color blue = Color(0xFF0A84FF);
  static const Color purple = Color(0xFFBF5AF2);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color textColor = Color(0xFFF5F5FA);
  static const Color muted = Color(0xFF636380);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: red,
          secondary: orange,
          surface: s1,
          background: bg,
          onPrimary: Colors.white,
          onSurface: textColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: s1,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 1,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: s1,
          selectedItemColor: red,
          unselectedItemColor: muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: s1,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? Colors.white : muted),
          trackColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? red : s3),
        ),
        fontFamily: 'Roboto',
      );
}
