import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/feedback_models.dart';
import 'preview_helpers.dart';
import 'preview_tokens.dart';
import '../../../core/constants/asset_server_config.dart';

/// Quiz sonuç diyaloğu önizlemesi.
///
/// Mobil uygulamadaki `quiz_dialogs.dart → _buildHeader` metodunun
/// adapte edilmiş versiyonu. Riverpod yerine doğrudan parametre geçişi,
/// Lottie.asset() yerine Lottie.network() kullanır.
///
/// Render kuralları:
/// - Arka plan: PreviewTokens.bgGradient (radial gradient)
/// - Glassmorphism kart: yarı saydam, 28px radius, blur efekti
/// - Lottie: 140x140, Asset Sunucu üzerinden
/// - Başlık: PlayfairDisplay, 28px, bold, başarılı→beyaz / başarısız→altın
/// - Mesaj: Nunito, 14px, textSecondary, satır yüksekliği 1.4
/// - Alt butonlar: deaktif placeholder (Tekrar Dene, Devam Et)
class QuizResultPreview extends StatelessWidget {
  const QuizResultPreview({
    super.key,
    required this.message,
    this.subcategory,
  });

  /// Önizlenecek feedback mesajı.
  final FeedbackMessageModel message;

  /// Alt kategori — başarı/başarısızlık belirleme için.
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    final isSuccess = isSuccessCategory(subcategory);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: PreviewTokens.bgGradient,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _buildGlassCard(isSuccess),
        ),
      ),
    );
  }

  Widget _buildGlassCard(bool isSuccess) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: PreviewTokens.surfaceGlass,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PreviewTokens.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation
              _buildLottie(),
              const SizedBox(height: 24),
              // Title
              _buildTitle(isSuccess),
              const SizedBox(height: 8),
              // Message
              _buildMessage(),
              const SizedBox(height: 32),
              // Bottom buttons (disabled placeholders)
              _buildButtons(isSuccess),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLottie() {
    final hasLottie =
        message.lottieAsset != null && message.lottieAsset!.isNotEmpty;

    if (hasLottie) {
      final url =
          AssetServerConfig.fileUrl('lottie/${message.lottieAsset}');
      return SizedBox(
        height: 140,
        width: 140,
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

  /// Lottie yükleme hatası durumunda emoji placeholder + dosya adı kırmızı.
  Widget _buildLottieError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          message.emoji.isNotEmpty ? message.emoji : '⚠️',
          style: const TextStyle(fontSize: 48),
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
    );
  }

  Widget _buildEmojiPlaceholder() {
    return SizedBox(
      height: 140,
      width: 140,
      child: Center(
        child: Text(
          message.emoji.isNotEmpty ? message.emoji : '🏆',
          style: const TextStyle(fontSize: 64),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isSuccess) {
    if (message.title.isEmpty) {
      return const Text(
        '(Başlık girilmemiş)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 28,
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: isSuccess ? Colors.white : PreviewTokens.goldStart,
      ),
    );
  }

  Widget _buildMessage() {
    if (message.message.isEmpty) {
      return const Text(
        '(Mesaj girilmemiş)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Color(0x80FFFFFF),
          height: 1.4,
        ),
      );
    }

    return Text(
      message.message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        color: Color(0xFFB0B0B0),
        height: 1.4,
      ),
    );
  }

  Widget _buildButtons(bool isSuccess) {
    return Row(
      children: [
        if (!isSuccess)
          Expanded(
            child: _buildDisabledButton('Tekrar Dene', Icons.refresh),
          ),
        if (!isSuccess) const SizedBox(width: 12),
        Expanded(
          child: _buildDisabledButton('Devam Et', Icons.arrow_forward),
        ),
      ],
    );
  }

  Widget _buildDisabledButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
