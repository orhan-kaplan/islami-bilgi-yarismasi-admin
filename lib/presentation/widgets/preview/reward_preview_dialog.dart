import 'package:flutter/material.dart';

import '../../../data/models/reward_model.dart';
import '../../../data/services/asset_path_utils.dart';
import 'phone_mockup_frame.dart';
import 'preview_tokens.dart';
import '../../../core/constants/asset_server_config.dart';

/// Shows a preview dialog demonstrating how a reward looks in the mobile app.
///
/// Displays two tab views inside a phone mockup:
/// 1. Collection card view (unlocked state)
/// 2. Quiz result "YENİ ÜNVAN KAZANDIN!" view
Future<void> showRewardPreviewDialog(
  BuildContext context, {
  required RewardModel reward,
}) {
  return showDialog(
    context: context,
    builder: (context) => RewardPreviewDialog(reward: reward),
  );
}

/// Preview dialog widget showing reward appearance in the mobile app.
class RewardPreviewDialog extends StatefulWidget {
  const RewardPreviewDialog({super.key, required this.reward});

  final RewardModel reward;

  @override
  State<RewardPreviewDialog> createState() => _RewardPreviewDialogState();
}

class _RewardPreviewDialogState extends State<RewardPreviewDialog> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final apiPath = AssetPathUtils.appPathToApiPath(widget.reward.assetImage);
    final imageUrl = AssetServerConfig.fileUrl(apiPath);

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
              const SizedBox(height: 8),
              // Tab selector
              _buildTabSelector(),
              const SizedBox(height: 16),
              // Phone mockup with selected tab content
              PhoneMockupFrame(
                child: _selectedTab == 0
                    ? _buildCollectionView(imageUrl)
                    : _buildQuizResultView(imageUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment<int>(
          value: 0,
          label: Text('Koleksiyon'),
          icon: Icon(Icons.grid_view_outlined),
        ),
        ButtonSegment<int>(
          value: 1,
          label: Text('Kazanım'),
          icon: Icon(Icons.emoji_events_outlined),
        ),
      ],
      selected: {_selectedTab},
      onSelectionChanged: (Set<int> selection) {
        setState(() {
          _selectedTab = selection.first;
        });
      },
      showSelectedIcon: false,
    );
  }

  /// Tab 1: Collection card view (unlocked state)
  Widget _buildCollectionView(String imageUrl) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: PreviewTokens.bgGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PreviewTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PreviewTokens.surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reward image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: PreviewTokens.surfaceGlass,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 48,
                        color: PreviewTokens.goldStart,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Title
                Text(
                  widget.reward.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PreviewTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                // Description
                Text(
                  widget.reward.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: PreviewTokens.textPrimary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                // "Açık" badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    '✓ Açık',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF81C784),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tab 2: Quiz result "YENİ ÜNVAN KAZANDIN!" view
  Widget _buildQuizResultView(String imageUrl) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: PreviewTokens.bgGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PreviewTokens.goldStart.withValues(alpha: 0.12),
                  PreviewTokens.goldEnd.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PreviewTokens.goldStart.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "YENİ ÜNVAN KAZANDIN!" text
                const Text(
                  'YENİ ÜNVAN KAZANDIN!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: PreviewTokens.goldStart,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Reward image with glow
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PreviewTokens.goldStart.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: PreviewTokens.goldEnd.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: PreviewTokens.surfaceGlass,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 60,
                          color: PreviewTokens.goldStart,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  widget.reward.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PreviewTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  widget.reward.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: PreviewTokens.textPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
