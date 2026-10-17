import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF030616);
  static const surface = Color(0xFF0B1230);
  static const cyan = Color(0xFF3BEAFF);
  static const blue = Color(0xFF1976FF);
  static const violet = Color(0xFF7C35FF);
  static const magenta = Color(0xFFFF32E6);
  static const queued = Color(0xFF71809E);
  static const success = Color(0xFF3EE79B);
  static const warning = Color(0xFFFFC857);
  static const failure = Color(0xFFFF5470);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          secondary: AppColors.magenta,
          surface: AppColors.surface,
          error: AppColors.failure,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xF20A0E24),
          indicatorColor: Color(0x447C35FF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
