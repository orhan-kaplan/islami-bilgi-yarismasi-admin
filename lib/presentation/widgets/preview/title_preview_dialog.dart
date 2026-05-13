import 'package:flutter/material.dart';

import '../../../data/models/feedback_models.dart';
import '../../../data/services/asset_path_utils.dart';
import 'phone_mockup_frame.dart';
import 'preview_tokens.dart';

/// Shows a preview dialog demonstrating how a player title looks in the mobile app.
///
/// Displays the dashboard header with:
/// - Greeting text + title name
/// - Gold rank chip (icon + title)
/// - Profile avatar with gold border
Future<void> showTitlePreviewDialog(
  BuildContext context, {
  required PlayerTitleModel title,
}) {
  return showDialog(
    context: context,
    builder: (context) => TitlePreviewDialog(title: title),
  );
}

/// Preview dialog widget showing title appearance in the mobile app dashboard.
class TitlePreviewDialog extends StatelessWidget {
  const TitlePreviewDialog({super.key, required this.title});

  final PlayerTitleModel title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Kapat',
                ),
              ),
              const SizedBox(height: 16),
              // Phone mockup with preview content
              PhoneMockupFrame(
                child: _buildPhoneContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneContent() {
    final hasProfileImage = title.profileImage.isNotEmpty;
    final apiPath = hasProfileImage
        ? AssetPathUtils.appPathToApiPath(title.profileImage)
        : '';
    final profileUrl =
        hasProfileImage ? 'http://localhost:8080/api/files/$apiPath' : '';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: PreviewTokens.bgGradient),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Dashboard header simulation
          Padding(
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
                          color: Color(0xB3FFFFFF),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Title + " Ahmet"
                      Text(
                        '${title.title.isNotEmpty ? title.title : "(Ünvan)"} Ahmet',
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
                _buildProfileAvatar(profileUrl),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Info section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PreviewTokens.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PreviewTokens.surfaceBorder),
              ),
              child: Column(
                children: [
                  Text(
                    'Gerekli Kitap: ${title.requiredBooks}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: Color(0xB3FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${title.requiredBooks}. kitabı bitiren kullanıcıya verilir',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: Color(0x80FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Placeholder blocks
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: PreviewTokens.goldGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PreviewTokens.goldStart.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.icon.isNotEmpty ? title.icon : '🌟',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 6),
          Text(
            title.title.isNotEmpty ? title.title : '(Ünvan)',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20), // Dark green text on gold
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String profileUrl) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PreviewTokens.goldStart, PreviewTokens.goldEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: PreviewTokens.goldStart.withValues(alpha: 0.22),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PreviewTokens.bgPrimary,
        ),
        child: profileUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  profileUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.person, size: 32, color: Colors.white54),
                  ),
                ),
              )
            : const Center(
                child: Icon(Icons.person, size: 32, color: Colors.white54),
              ),
      ),
    );
  }
}
