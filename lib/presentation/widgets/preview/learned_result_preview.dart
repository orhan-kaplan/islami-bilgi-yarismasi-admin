import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/feedback_models.dart';
import 'preview_helpers.dart';
import 'preview_tokens.dart';

/// Öğrenilen quiz sonuç ekranı önizlemesi.
///
/// Mobil uygulamadaki `learned_quiz_screen.dart → _LearnedQuizResultScreen`
/// widget'ının adapte edilmiş versiyonu.
///
/// Render kuralları:
/// - Lottie: 180px yükseklik, Lottie.network(), shouldRepeat döngü kontrolü
/// - Başlık: PlayfairDisplay, 32px, bold, vurgu renginde
/// - Alt başlık: Nunito, 16px, textSecondary
/// - Yüzde: Nunito, 48px, bold, vurgu renginde (subcategory'den)
/// - İstatistik kutuları: placeholder verilerle (Toplam: 10, Öğrenilen: 7, Kalan: 3)
/// - Vurgu rengi: accentColorForPercentage ile belirlenir
class LearnedQuizResultPreview extends StatelessWidget {
  const LearnedQuizResultPreview({
    super.key,
    required this.message,
    this.subcategory,
  });

  /// Önizlenecek feedback mesajı.
  final FeedbackMessageModel message;

  /// Alt kategori: '100', '75', '50', '25', '0'.
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    final percentage = percentageForSubcategory(subcategory);
    final accentColor = accentColorForPercentage(percentage);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: PreviewTokens.bgGradient,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            // Lottie animation
            _buildLottie(),
            const SizedBox(height: 24),
            // Title
            _buildTitle(accentColor),
            const SizedBox(height: 8),
            // Subtitle (message)
            _buildSubtitle(),
            const SizedBox(height: 24),
            // Percentage
            _buildPercentage(percentage, accentColor),
            const SizedBox(height: 32),
            // Stats boxes
            _buildStatsBoxes(accentColor),
            const SizedBox(height: 32),
            // Placeholder button
            _buildPlaceholderButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLottie() {
    final hasLottie =
        message.lottieAsset != null && message.lottieAsset!.isNotEmpty;

    if (hasLottie) {
      final url =
          'http://localhost:8080/api/files/lottie/${message.lottieAsset}';
      return SizedBox(
        height: 180,
        child: Lottie.network(
          url,
          fit: BoxFit.contain,
          repeat: message.shouldRepeat,
          errorBuilder: (context, error, stackTrace) {
            return _buildLottieError();
          },
        ),
      );
    }

    return _buildEmojiPlaceholder();
  }

  Widget _buildLottieError() {
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message.emoji.isNotEmpty ? message.emoji : '⚠️',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 4),
          Text(
            message.lottieAsset ?? '',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.red,
              fontFamily: 'Nunito',
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPlaceholder() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          message.emoji.isNotEmpty ? message.emoji : '📚',
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }

  Widget _buildTitle(Color accentColor) {
    if (message.title.isEmpty) {
      return const Text(
        '(Başlık girilmemiş)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: Color(0x80FFFFFF),
        ),
      );
    }

    return Text(
      message.title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
    );
  }

  Widget _buildSubtitle() {
    if (message.message.isEmpty) {
      return const Text(
        '(Mesaj girilmemiş)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Color(0x80FFFFFF),
        ),
      );
    }

    return Text(
      message.message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        color: PreviewTokens.textSecondary,
      ),
    );
  }

  Widget _buildPercentage(int percentage, Color accentColor) {
    return Text(
      '%$percentage',
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
    );
  }

  Widget _buildStatsBoxes(Color accentColor) {
    return Row(
      children: [
        _buildStatBox('Toplam', '10', accentColor),
        const SizedBox(width: 12),
        _buildStatBox('Öğrenilen', '7', accentColor),
        const SizedBox(width: 12),
        _buildStatBox('Kalan', '3', accentColor),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: PreviewTokens.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PreviewTokens.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: PreviewTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_forward, size: 16, color: Colors.white38),
          SizedBox(width: 6),
          Text(
            'Devam Et',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
