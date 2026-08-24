import 'package:flutter/material.dart';

/// `ColorScheme`'de karşılığı olmayan iki semantik renk.
///
/// Warning ve success daha önce ekranlarda `Colors.orange` / `Colors.green`
/// olarak sabitlenmişti; turuncu açık temada beyaz üstünde okunmuyordu.
/// Tema başına ayarlanan token'lar her iki parlaklıkta da okunur kalır.
@immutable
class AdminSemanticColors extends ThemeExtension<AdminSemanticColors> {
  const AdminSemanticColors({
    required this.warning,
    required this.success,
  });

  /// Warning-level validasyon bulguları.
  final Color warning;

  /// "Sorun yok" durumları.
  final Color success;

  static const light = AdminSemanticColors(
    warning: Color(0xFF9A5B00),
    success: Color(0xFF1B7F3B),
  );

  static const dark = AdminSemanticColors(
    warning: Color(0xFFFFB74D),
    success: Color(0xFF66BB6A),
  );

  @override
  AdminSemanticColors copyWith({Color? warning, Color? success}) {
    return AdminSemanticColors(
      warning: warning ?? this.warning,
      success: success ?? this.success,
    );
  }

  @override
  AdminSemanticColors lerp(
    ThemeExtension<AdminSemanticColors>? other,
    double t,
  ) {
    if (other is! AdminSemanticColors) return this;
    return AdminSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Tema uzantısını okumanın kısa yolu.
///
/// Uzantı kayıtlı değilse (temasız bir `MaterialApp` altında) parlaklığa
/// uygun varsayılana düşer, böylece ekranlar null kontrolü taşımaz.
extension AdminSemanticColorsContext on BuildContext {
  AdminSemanticColors get adminColors {
    final theme = Theme.of(this);
    return theme.extension<AdminSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AdminSemanticColors.dark
            : AdminSemanticColors.light);
  }
}

/// Material 3 theme for the İlim Yolculuğu Admin tool.
///
/// Uses a teal/green color scheme appropriate for an Islamic content admin tool.
final ThemeData adminTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B), // Teal 600
    brightness: Brightness.light,
  ),
  extensions: const [AdminSemanticColors.light],
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
  extensions: const [AdminSemanticColors.dark],
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
