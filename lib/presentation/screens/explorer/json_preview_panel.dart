import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/content_state.dart';
import '../../providers/content_providers.dart';
import 'content_explorer_screen.dart';

/// Read-only panel displaying the JSON representation of the currently
/// selected item in the content tree.
///
/// Uses [JsonEncoder.withIndent] for pretty-printing and displays the output
/// in a [SelectableText] widget with a monospace font.
class JsonPreviewPanel extends ConsumerWidget {
  final SelectedItem? selectedItem;

  const JsonPreviewPanel({super.key, required this.selectedItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedItem == null) {
      return const Center(
        child: Text(
          'Select an item to preview its JSON',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      );
    }

    // Henüz oluşturulmamış kayıt "Item not found" diyordu: öğe kaybolmuş
    // gibi okunuyordu.
    final item = selectedItem!;
    if (item is CreateSeries ||
        item is CreateBook ||
        item is CreateLevel ||
        item is CreateQuestion) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Not saved yet — fill in the form and save to see its JSON.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final state = ref.watch(contentStateProvider);
    final json = _resolveJson(state, item);

    if (json == null) {
      return const Center(
        child: Text(
          'Item not found',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      );
    }

    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(json);

    // Uzun değerler (asset yolları) panelden taşıyor ve erişilemiyordu.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          formatted,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// Resolves the selected item to its JSON map from the content state.
  Map<String, dynamic>? _resolveJson(
    ContentState state,
    SelectedItem item,
  ) {
    switch (item) {
      case SelectedSeries(:final seriesId):
        final series = state.series.where((s) => s.id == seriesId).firstOrNull;
        return series?.toJson();

      case SelectedBook(:final bookId):
        final book = state.books.where((b) => b.id == bookId).firstOrNull;
        return book?.toJson();

      case SelectedLevel(:final contentFile, :final levelId):
        final levels = state.contentFiles[contentFile];
        if (levels == null) return null;
        final level = levels.where((l) => l.id == levelId).firstOrNull;
        return level?.toJson();

      case SelectedQuestion(
        :final contentFile,
        :final levelId,
        :final questionIndex,
      ):
        final levels = state.contentFiles[contentFile];
        if (levels == null) return null;
        final level = levels.where((l) => l.id == levelId).firstOrNull;
        if (level == null) return null;
        if (questionIndex < 0 || questionIndex >= level.questions.length) {
          return null;
        }
        return level.questions[questionIndex].toJson();

      case CreateSeries():
      case CreateBook():
      case CreateLevel():
      case CreateQuestion():
        return null;
    }
  }
}
