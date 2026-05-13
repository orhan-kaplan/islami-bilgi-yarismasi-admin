import 'package:flutter/painting.dart';

/// Mobil uygulamadaki DesignTokens'ın önizleme için gerekli alt kümesi.
///
/// Bu sınıf, admin aracındaki feedback önizleme widget'larının
/// mobil uygulamadaki görünümü doğru şekilde yansıtabilmesi için
/// gerekli renk, gradient ve stil değerlerini tanımlar.
abstract class PreviewTokens {
  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 ARKA PLAN RENKLERİ
  // ══════════════════════════════════════════════════════════════════════════

  /// Spotlight merkezi - Açık zümrüt
  static const Color bgPrimary = Color(0xFF1A4D43);

  /// Orta geçiş tonu
  static const Color bgSecondary = Color(0xFF0D3329);

  /// Koyu orman yeşili
  static const Color bgDeep = Color(0xFF072420);

  /// En koyu - Neredeyse siyah, kenarlar
  static const Color bgVoid = Color(0xFF051A16);

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 ALTIN TEMA
  // ══════════════════════════════════════════════════════════════════════════

  /// Altın gradient başlangıç
  static const Color goldStart = Color(0xFFFFC107);

  /// Altın gradient bitiş - Açık amber
  static const Color goldEnd = Color(0xFFFFD54F);

  /// Altın üzerindeki metin/ikon rengi
  static const Color goldOnColor = Color(0xFF1B5E20);

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 METİN RENKLERİ
  // ══════════════════════════════════════════════════════════════════════════

  /// Birincil metin - Off-white
  static const Color textPrimary = Color(0xFFF5F5F5);

  /// İkincil metin - %80 beyaz
  static const Color textSecondary = Color(0xCCFFFFFF);

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 LEARNED FEEDBACK RENKLERİ
  // ══════════════════════════════════════════════════════════════════════════

  /// %100 başarı - Altın
  static const Color learnedFeedbackGold = Color(0xFFFFD700);

  /// %75 başarı - Yeşil
  static const Color learnedFeedbackGreen = Color(0xFF4CAF50);

  /// %50 başarı - Mavi
  static const Color learnedFeedbackBlue = Color(0xFF2196F3);

  /// %25 başarı - Turuncu
  static const Color learnedFeedbackOrange = Color(0xFFFF9800);

  /// %0 başarı - Kırmızı
  static const Color learnedFeedbackRed = Color(0xFFF44336);

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 YÜZEY RENKLERİ
  // ══════════════════════════════════════════════════════════════════════════

  /// Cam kartları dolgu - %8 beyaz
  static const Color surfaceGlass = Color(0x14FFFFFF);

  /// Cam kartları kenarlık - %15 beyaz
  static const Color surfaceBorder = Color(0x26FFFFFF);

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 GRADİENT'LER
  // ══════════════════════════════════════════════════════════════════════════

  /// Ana arka plan radial gradient (AppBackground)
  static const RadialGradient bgGradient = RadialGradient(
    center: Alignment(0.0, -0.6),
    radius: 1.4,
    colors: [bgPrimary, bgSecondary, bgDeep, bgVoid],
    stops: [0.0, 0.35, 0.65, 1.0],
  );

  /// Altın linear gradient
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldStart, goldEnd],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 ÖZEL RENKLER
  // ══════════════════════════════════════════════════════════════════════════

  /// Comeback dialog arka plan rengi
  static const Color comebackBg = Color(0xFF1B5E20);

  /// Emerald accent (doğru cevap)
  static const Color emeraldAccent = Color(0xFF10B981);
}
