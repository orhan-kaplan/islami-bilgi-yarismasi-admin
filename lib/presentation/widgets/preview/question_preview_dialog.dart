import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';
import 'phone_mockup_frame.dart';
import 'preview_tokens.dart';

/// Shows a dialog with a phone mockup previewing how the question
/// looks in the mobile quiz app.
Future<void> showQuestionPreviewDialog(
  BuildContext context, {
  required QuestionModel question,
}) {
  return showDialog(
    context: context,
    builder: (context) => _QuestionPreviewDialog(question: question),
  );
}

class _QuestionPreviewDialog extends StatelessWidget {
  const _QuestionPreviewDialog({required this.question});

  final QuestionModel question;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PhoneMockupFrame(
        child: Container(
          decoration: const BoxDecoration(
            gradient: PreviewTokens.bgGradient,
          ),
          // Soru metni ve seçenekler serbest uzunlukta olabildiğinden sabit
          // 693px çerçeveyi aşabilir; SingleChildScrollView ile sarılmazsa
          // taşan kısım ClipRRect tarafından sessizce gizlenir.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 16),
                _buildQuestionCard(),
                const SizedBox(height: 16),
                _buildOptionsArea(),
                if (question.explanation != null &&
                    question.explanation!.isNotEmpty)
                  _buildExplanationBox(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Simplified header bar: question number, score, lives.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Question counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PreviewTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PreviewTokens.surfaceBorder),
            ),
            child: const Text(
              '1/10',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: PreviewTokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PreviewTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PreviewTokens.surfaceBorder),
            ),
            child: const Text(
              '0',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: PreviewTokens.goldStart,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Lives
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PreviewTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PreviewTokens.surfaceBorder),
            ),
            child: const Text(
              '❤️❤️❤️',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Glassmorphism question card.
  Widget _buildQuestionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: Center(
          child: Text(
            question.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the options area based on question type.
  Widget _buildOptionsArea() {
    return switch (question.type) {
      'multiple_choice' => _buildMultipleChoiceOptions(),
      'true_false' => _buildTrueFalseOptions(),
      'matching' => _buildMatchingOptions(),
      'sorting' => _buildSortingOptions(),
      _ => _buildMultipleChoiceOptions(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MULTIPLE CHOICE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMultipleChoiceOptions() {
    final options = [
      ('A', question.optionA),
      ('B', question.optionB),
      ('C', question.optionC),
      ('D', question.optionD),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: options
            .map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildOptionCard(
                    letter: opt.$1,
                    text: opt.$2,
                    isCorrect: opt.$1 == question.correctOption,
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRUE / FALSE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTrueFalseOptions() {
    final options = [
      ('A', 'Doğru'),
      ('B', 'Yanlış'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: options
            .map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildOptionCard(
                    letter: opt.$1,
                    text: opt.$2,
                    isCorrect: opt.$1 == question.correctOption,
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MATCHING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMatchingOptions() {
    final pairs = [
      question.optionA,
      question.optionB,
      question.optionC,
      question.optionD,
    ].where((o) => o.contains('|')).toList();

    final leftItems = pairs.map((p) => p.split('|')[0].trim()).toList();
    final rightItems = pairs.map((p) => p.split('|')[1].trim()).toList();

    // Shuffle right side for display (deterministic based on content)
    final shuffledRight = List<String>.from(rightItems)..shuffle();

    final colors = [
      Colors.amber,
      Colors.cyan,
      Colors.pinkAccent,
      Colors.lightGreenAccent,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left column
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(leftItems.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors[i % colors.length].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors[i % colors.length].withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      leftItems[i],
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }),
            ),
          ),
          // Connection indicator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.compare_arrows, color: Colors.white38, size: 18),
                SizedBox(height: 20),
                Icon(Icons.compare_arrows, color: Colors.white38, size: 18),
                SizedBox(height: 20),
                Icon(Icons.compare_arrows, color: Colors.white38, size: 18),
                SizedBox(height: 20),
                Icon(Icons.compare_arrows, color: Colors.white38, size: 18),
              ],
            ),
          ),
          // Right column (shuffled)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(shuffledRight.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PreviewTokens.surfaceGlass,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PreviewTokens.surfaceBorder),
                    ),
                    child: Text(
                      shuffledRight[i],
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
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

  // ─────────────────────────────────────────────────────────────────────────
  // SORTING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSortingOptions() {
    final items = [
      question.optionA,
      question.optionB,
      question.optionC,
      question.optionD,
    ].where((o) => o.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: PreviewTokens.surfaceGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PreviewTokens.surfaceBorder),
              ),
              child: Row(
                children: [
                  // Order number badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: PreviewTokens.goldStart.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          color: PreviewTokens.goldStart,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Item text
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Drag handle icon
                  const Icon(
                    Icons.drag_handle,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a single option card (used by multiple_choice and true_false).
  Widget _buildOptionCard({
    required String letter,
    required String text,
    required bool isCorrect,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect
            ? PreviewTokens.emeraldAccent.withValues(alpha: 0.18)
            : PreviewTokens.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect
              ? PreviewTokens.emeraldAccent.withValues(alpha: 0.7)
              : PreviewTokens.surfaceBorder,
          width: isCorrect ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Text(
            letter,
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: PreviewTokens.goldStart,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Nunito',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isCorrect)
            const Icon(
              Icons.check_circle,
              color: PreviewTokens.emeraldAccent,
              size: 20,
            ),
        ],
      ),
    );
  }

  /// Explanation info box shown at the bottom.
  Widget _buildExplanationBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PreviewTokens.goldStart.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PreviewTokens.goldStart.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: PreviewTokens.goldStart,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question.explanation!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: PreviewTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
