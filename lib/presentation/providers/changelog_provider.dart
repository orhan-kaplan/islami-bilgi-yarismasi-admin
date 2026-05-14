import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import 'content_providers.dart';
import 'history_providers.dart';

/// Represents a single change entry in the changelog.
class ChangeEntry {
  final String description; // e.g., "3 soru eklendi"
  final String file; // e.g., "data/content/book_1.json"
  final ChangeType type; // added, modified, removed

  const ChangeEntry({
    required this.description,
    required this.file,
    required this.type,
  });
}

enum ChangeType { added, modified, removed }

/// Provider that computes a detailed changelog between saved baseline and current state.
final changelogProvider = Provider<List<ChangeEntry>>((ref) {
  final baseline = ref.watch(savedBaselineProvider);
  final current = ref.watch(contentStateProvider);
  if (baseline == null) return [];

  return _computeChangelog(baseline, current);
});

List<ChangeEntry> _computeChangelog(ContentState baseline, ContentState current) {
  final entries = <ChangeEntry>[];

  // Series changes
  if (current.series != baseline.series) {
    final added = current.series.length - baseline.series.length;
    if (added > 0) {
      entries.add(ChangeEntry(
        description: '$added seri eklendi',
        file: 'series.json',
        type: ChangeType.added,
      ));
    } else if (added < 0) {
      entries.add(ChangeEntry(
        description: '${-added} seri silindi',
        file: 'series.json',
        type: ChangeType.removed,
      ));
    } else {
      entries.add(const ChangeEntry(
        description: 'Seriler düzenlendi',
        file: 'series.json',
        type: ChangeType.modified,
      ));
    }
  }

  // Books changes
  if (current.books != baseline.books) {
    final added = current.books.length - baseline.books.length;
    if (added > 0) {
      entries.add(ChangeEntry(
        description: '$added kitap eklendi',
        file: 'books.json',
        type: ChangeType.added,
      ));
    } else if (added < 0) {
      entries.add(ChangeEntry(
        description: '${-added} kitap silindi',
        file: 'books.json',
        type: ChangeType.removed,
      ));
    } else {
      entries.add(const ChangeEntry(
        description: 'Kitaplar düzenlendi',
        file: 'books.json',
        type: ChangeType.modified,
      ));
    }
  }

  // Rewards changes
  if (current.rewards != baseline.rewards) {
    final added = current.rewards.length - baseline.rewards.length;
    if (added > 0) {
      entries.add(ChangeEntry(
        description: '$added ödül eklendi',
        file: 'rewards.json',
        type: ChangeType.added,
      ));
    } else if (added < 0) {
      entries.add(ChangeEntry(
        description: '${-added} ödül silindi',
        file: 'rewards.json',
        type: ChangeType.removed,
      ));
    } else {
      entries.add(const ChangeEntry(
        description: 'Ödüller düzenlendi',
        file: 'rewards.json',
        type: ChangeType.modified,
      ));
    }
  }

  // Hadiths changes
  if (current.hadiths != baseline.hadiths) {
    final added = current.hadiths.length - baseline.hadiths.length;
    if (added > 0) {
      entries.add(ChangeEntry(
        description: '$added hadis eklendi',
        file: 'hadiths.json',
        type: ChangeType.added,
      ));
    } else if (added < 0) {
      entries.add(ChangeEntry(
        description: '${-added} hadis silindi',
        file: 'hadiths.json',
        type: ChangeType.removed,
      ));
    } else {
      entries.add(const ChangeEntry(
        description: 'Hadisler düzenlendi',
        file: 'hadiths.json',
        type: ChangeType.modified,
      ));
    }
  }

  // Content files (levels/questions) changes
  final allKeys = <String>{
    ...baseline.contentFiles.keys,
    ...current.contentFiles.keys,
  };
  for (final key in allKeys) {
    final baselineLevels = baseline.contentFiles[key] ?? [];
    final currentLevels = current.contentFiles[key] ?? [];

    if (baselineLevels != currentLevels) {
      // Count question differences
      final baselineQCount =
          baselineLevels.fold<int>(0, (sum, l) => sum + l.questions.length);
      final currentQCount =
          currentLevels.fold<int>(0, (sum, l) => sum + l.questions.length);
      final qDiff = currentQCount - baselineQCount;

      final levelDiff = currentLevels.length - baselineLevels.length;

      final parts = <String>[];
      if (levelDiff > 0) parts.add('$levelDiff level eklendi');
      if (levelDiff < 0) parts.add('${-levelDiff} level silindi');
      if (qDiff > 0) parts.add('$qDiff soru eklendi');
      if (qDiff < 0) parts.add('${-qDiff} soru silindi');
      if (parts.isEmpty) parts.add('İçerik düzenlendi');

      // Find book name for this content file
      final book =
          current.books.where((b) => b.contentFile == key).firstOrNull;
      final bookName = book?.title ?? key;

      entries.add(ChangeEntry(
        description: '$bookName: ${parts.join(", ")}',
        file: 'content/$key',
        type: qDiff != 0 || levelDiff != 0
            ? (qDiff > 0 || levelDiff > 0
                ? ChangeType.added
                : ChangeType.removed)
            : ChangeType.modified,
      ));
    }
  }

  return entries;
}
