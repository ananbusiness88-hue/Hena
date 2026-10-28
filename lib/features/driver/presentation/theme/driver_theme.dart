import 'package:flutter/material.dart';

abstract final class DriverTheme {
  static const background = Color(0xFFF7FBF9);
  static const header = Color(0xFFDDF4E8);
  static const primary = Color(0xFF36B878);
  static const primaryDark = Color(0xFF218957);

  static const softBlue = Color(0xFFE3F2FC);
  static const blue = Color(0xFF4D9FD8);

  static const softOrange = Color(0xFFFFF1DE);
  static const orange = Color(0xFFF59E0B);

  static const text = Color(0xFF243447);
  static const mutedText = Color(0xFF718096);
  static const border = Color(0xFFE3ECE7);
  static const white = Colors.white;

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: white,
        surface: white,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: header,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: text,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: text,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: text,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: mutedText,
          height: 1.5,
        ),
      ),
    );
  }
}