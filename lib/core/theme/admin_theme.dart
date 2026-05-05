import 'package:flutter/material.dart';

/// Material 3 theme for the İlim Yolculuğu Admin tool.
///
/// Uses a teal/green color scheme appropriate for an Islamic content admin tool.
final ThemeData adminTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B), // Teal 600
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    elevation: 1,
    margin: EdgeInsets.all(8),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    filled: true,
  ),
);

final ThemeData adminDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B),
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    elevation: 1,
    margin: EdgeInsets.all(8),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    filled: true,
  ),
);
