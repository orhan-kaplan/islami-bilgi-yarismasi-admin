import 'package:flutter/material.dart';

import '../../../data/models/feedback_models.dart';
import 'preview_tokens.dart';

/// Dashboard selamlama önizlemesi.
///
/// Mobil uygulamadaki `dashboard_header.dart` ve `dashboard_actions.dart`
/// widget'larının adapte edilmiş versiyonu.
///
/// Kategoriye göre farklı render:
/// - **time:** DashboardTopRow — "Esselamü Aleyküm," + title + " Ahmet"
/// - **comeback:** AlertDialog — koyu yeşil, emoji, başlık, mesaj, buton
/// - **streak:** Bento grid streak kartı — alev ikonu + sayı
class DashboardPreview extends StatelessWidget {
  const DashboardPreview({
    super.key,
    required this.message,
    required this.category,
    this.subcategory,
  });

  /// Önizlenecek feedback mesajı.
  final FeedbackMessageModel message;

  /// Kategori: 'time', 'comeback', 'streak'.
  final String category;

  /// Alt kategori (ör: 'morning', 'afternoon').
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: PreviewTokens.bgGradient,
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Dashboard top row (always shown)
          _buildDashboardTopRow(),
          const SizedBox(height: 16),
          // Category-specific content
          Expanded(
            child: _buildCategoryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTopRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: greeting + title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Esselamü Aleyküm,"
                const Text(
                  'Esselamü Aleyküm,',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xB3FFFFFF), // white70
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                // Title + " Ahmet"
                Text(
                  _buildTitleText(),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Rank chip
                _buildRankChip(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right side: profile avatar
          _buildProfileAvatar(),
        ],
      ),
    );
  }

  String _buildTitleText() {
    if (category == 'time') {
      final title = message.title.isNotEmpty ? message.title : '(Başlık girilmemiş)';
      return '$title Ahmet';
    }
    return 'Seher Bülbülü Ahmet';
  }

  Widget _buildRankChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PreviewTokens.goldStart.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PreviewTokens.goldStart.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏅', style: TextStyle(fontSize: 13)),
          SizedBox(width: 6),
          Text(
            'Hafız Adayı',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PreviewTokens.goldEnd,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PreviewTokens.goldStart,
          width: 3,
        ),
      ),
      child: const CircleAvatar(
        radius: 30,
        backgroundColor: PreviewTokens.bgSecondary,
        child: Icon(
          Icons.person,
          size: 32,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (category) {
      case 'comeback':
        return _buildComebackDialog();
      case 'streak':
        return _buildStreakCard();
      case 'time':
      default:
        return _buildPlaceholderBlocks();
    }
  }

  /// Comeback kategorisi: AlertDialog stili.
  Widget _buildComebackDialog() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PreviewTokens.bgDeep,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji
            Text(
              message.emoji.isNotEmpty ? message.emoji : '👋',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            // Title
            _buildComebackTitle(),
            const SizedBox(height: 12),
            // Message
            _buildComebackMessage(),
            const SizedBox(height: 24),
            // "DEVAM ET" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  disabledBackgroundColor: Colors.amber.withValues(alpha: 0.7),
                  foregroundColor: Colors.black87,
                  disabledForegroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'DEVAM ET',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComebackTitle() {
    if (message.title.isEmpty) {
      return const Text(
        '(Başlık girilmemiş)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: Color(0x80FFFFFF),
        ),
      );
    }

    return Text(
      message.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildComebackMessage() {
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
        color: Color(0xB3FFFFFF), // white70
      ),
    );
  }

  /// Streak kategorisi: Bento grid streak kartı.
  Widget _buildStreakCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Streak card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PreviewTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PreviewTokens.surfaceBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message.emoji.isNotEmpty ? message.emoji : '🔥',
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: 12),
                Text(
                  subcategory ?? '7',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gün Serisi',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Streak message
          if (message.title.isNotEmpty || message.message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PreviewTokens.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PreviewTokens.surfaceBorder),
              ),
              child: Column(
                children: [
                  if (message.title.isNotEmpty)
                    Text(
                      message.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (message.title.isNotEmpty && message.message.isNotEmpty)
                    const SizedBox(height: 8),
                  if (message.message.isNotEmpty)
                    Text(
                      message.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                ],
              ),
            ),
          const Spacer(),
          // Placeholder blocks
          ..._buildGreyPlaceholders(2),
        ],
      ),
    );
  }

  /// Time kategorisi ve diğerleri: gri placeholder bloklar.
  Widget _buildPlaceholderBlocks() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _buildGreyPlaceholders(4),
      ),
    );
  }

  List<Widget> _buildGreyPlaceholders(int count) {
    return List.generate(count, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
      );
    });
  }
}
