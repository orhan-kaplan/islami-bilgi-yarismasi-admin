import 'package:flutter/material.dart';

/// Gerçekçi telefon mockup çerçevesi — 9:19.5 en-boy oranı.
///
/// Mobil cihaz görünümü sağlar:
/// - Koyu renkli çerçeve
/// - 40px borderRadius
/// - 3px border (grey.shade700)
/// - Gölge efekti
/// - İçerik alanını ClipRRect ile kırpar (overflow gizli)
class PhoneMockupFrame extends StatelessWidget {
  const PhoneMockupFrame({super.key, required this.child});

  /// İçerik widget'ı — telefon ekranı içinde gösterilecek.
  final Widget child;

  /// Telefon genişliği.
  static const double frameWidth = 320;

  /// Telefon yüksekliği — 9:19.5 oranı (320 * 19.5 / 9 ≈ 693).
  static const double frameHeight = 693;

  /// Çerçeve köşe yuvarlaklığı.
  static const double frameBorderRadius = 40;

  /// İçerik alanı köşe yuvarlaklığı (çerçeve - border genişliği).
  static const double contentBorderRadius = 37;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: frameWidth,
      height: frameHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(frameBorderRadius),
        border: Border.all(color: Colors.grey.shade700, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(contentBorderRadius),
        child: child,
      ),
    );
  }
}
