import 'package:flutter/material.dart';

abstract final class AppColors {
  static const orange = Color(0xFFF97316);
  static const orangeSoft = Color(0xFFFFF1E7);
  static const ink = Color(0xFF25282D);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE7E9ED);
  static const canvas = Color(0xFFF3F4F6);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFFF0F0);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFEAF8EF);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAFAFA),
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
