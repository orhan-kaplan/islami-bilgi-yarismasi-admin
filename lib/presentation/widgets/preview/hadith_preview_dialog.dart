import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models/hadith_model.dart';
import 'phone_mockup_frame.dart';
import 'preview_tokens.dart';

/// Shows a preview dialog demonstrating how a hadith looks in the mobile app dashboard.
///
/// Displays the hadith quote card as it appears on the dashboard:
/// - Gold quote icon
/// - Hadith text (PlayfairDisplay, italic)
/// - Source with gold gradient
Future<void> showHadithPreviewDialog(
  BuildContext context, {
  required HadithModel hadith,
}) {
  return showDialog(
    context: context,
    builder: (context) => HadithPreviewDialog(hadith: hadith),
  );
}

/// Preview dialog widget showing hadith appearance in the mobile app dashboard.
class HadithPreviewDialog extends StatelessWidget {
  const HadithPreviewDialog({super.key, required this.hadith});

  final HadithModel hadith;

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
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: PreviewTokens.bgGradient),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Dashboard header placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Esselamü Aleyküm,',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Seher Bülbülü Ahmet',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: PreviewTokens.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🏅 Hafız Adayı',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 13,
                            color: PreviewTokens.goldOnColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: PreviewTokens.goldStart, width: 3),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: PreviewTokens.bgSecondary,
                    child: Icon(Icons.person, size: 28, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Hadith quote card — the main preview content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF05231A).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gold quote icon
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            PreviewTokens.goldStart,
                            PreviewTokens.goldEnd,
                          ],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.format_quote_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Hadith text
                      Text(
                        hadith.text,
                        textAlign: TextAlign.center,
                        // Mobildeki dashboard_hadith.dart aynı kartı maxLines: 3
                        // ile kırpıyor — önizleme fazla satır gösterirse editör
                        // mobilde kesilecek metni "sığıyor" sanabilir.
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Gold source text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            PreviewTokens.goldEnd,
                            PreviewTokens.goldStart,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          '— ${hadith.source}',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Placeholder blocks below
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(2, (index) {
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
}
