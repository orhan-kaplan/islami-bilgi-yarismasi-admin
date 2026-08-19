import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_importer.dart';

ContentState _populatedState() {
  return const ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Series',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: 'A',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Book',
        description: 'Desc',
        assetImage: 'assets/images/book.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [
        LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Cat',
          levelOrder: 1,
          title: 'Level',
          unlockScore: 0,
          questions: [],
        ),
      ],
    },
    rewards: [
      RewardModel(
        unlockBookId: 1,
        title: 'Reward',
        description: 'Desc',
        assetImage: 'assets/images/reward.png',
      ),
    ],
    hadiths: [
      HadithModel(text: 'Hadith', source: 'Source'),
    ],
  );
}

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

void main() {
  group('hasBlockingErrors', () {
    test('warnings alone do not block import', () {
      const issues = [
        ImportIssue(
          fileName: 'hadiths.json',
          message: 'File not found in ZIP archive',
          severity: ImportIssueSeverity.warning,
        ),
      ];
      expect(hasBlockingErrors(issues), isFalse);
    });

    test('a single error blocks import', () {
      const issues = [
        ImportIssue(
          fileName: 'series.json',
          message: 'Parse error',
          severity: ImportIssueSeverity.error,
        ),
        ImportIssue(
          fileName: 'hadiths.json',
          message: 'File not found in ZIP archive',
          severity: ImportIssueSeverity.warning,
        ),
      ];
      expect(hasBlockingErrors(issues), isTrue);
    });
  });

  group('ZipImporter unrecognized archives', () {
    test('a ZIP wrapped in an extra folder reports an error, not warnings', () {
      // Kullanıcı export ZIP'ini bir klasöre koyup yeniden sıkıştırdığında
      // hiçbir dosya tanınmıyordu; sonuç boş ContentState + yalnızca warning'di.
      final bytes = _zip({
        'export/data/series.json': '[]',
        'export/data/books.json': '[]',
        'export/data/content/book_1.json': '{"levels": []}',
      });

      final (state, issues) = ZipImporter().importZip(bytes);

      expect(state.series, isEmpty);
      expect(
        issues.where((i) => i.severity == ImportIssueSeverity.error),
        isNotEmpty,
        reason: 'nothing was recognized, so the import must be blocked',
      );
      expect(hasBlockingErrors(issues), isTrue);
    });

    test('a normal ZIP with a missing file stays warning-only', () {
      final bytes = _zip({
        'series.json': '[]',
        'books.json': '[]',
        'rewards.json': '[]',
      });

      final (_, issues) = ZipImporter().importZip(bytes);

      expect(hasBlockingErrors(issues), isFalse);
      expect(
        issues.where((i) => i.fileName == 'hadiths.json'),
        isNotEmpty,
      );
    });

    test('a content-only ZIP counts as recognized', () {
      final bytes = _zip({
        'content/book_1.json': jsonEncode({'levels': <dynamic>[]}),
      });

      final (_, issues) = ZipImporter().importZip(bytes);

      expect(hasBlockingErrors(issues), isFalse);
    });
  });

  group('mergeImportedSlices', () {
    test('a books-only import leaves the other slices untouched', () {
      final current = _populatedState();
      const imported = ContentState(
        series: [],
        books: [
          BookModel(
            id: 2,
            title: 'Imported Book',
            description: 'Desc',
            assetImage: 'assets/images/book_2.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_2.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final merged = mergeImportedSlices(current, imported, {'books.json'});

      expect(merged.books.single.title, 'Imported Book');
      expect(merged.series, current.series);
      expect(merged.rewards, current.rewards);
      expect(merged.hadiths, current.hadiths);
      expect(merged.contentFiles.keys, contains('book_1.json'));
    });

    test('an explicitly provided empty file does clear its slice', () {
      final current = _populatedState();
      const imported = ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final merged = mergeImportedSlices(current, imported, {'hadiths.json'});

      expect(merged.hadiths, isEmpty);
      expect(merged.series, current.series);
      expect(merged.books, current.books);
    });

    test('imported content files overwrite by key and keep the rest', () {
      final current = _populatedState();
      const imported = ContentState(
        series: [],
        books: [],
        contentFiles: {
          'book_2.json': <LevelModel>[],
        },
        rewards: [],
        hadiths: [],
      );

      final merged = mergeImportedSlices(current, imported, {'books.json'});

      expect(merged.contentFiles.keys, containsAll(['book_1.json', 'book_2.json']));
      expect(merged.contentFiles['book_1.json'], current.contentFiles['book_1.json']);
    });

    test('a full import replaces every provided slice', () {
      final current = _populatedState();
      const imported = ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final merged = mergeImportedSlices(
        current,
        imported,
        {'series.json', 'books.json', 'rewards.json', 'hadiths.json'},
      );

      expect(merged.series, isEmpty);
      expect(merged.books, isEmpty);
      expect(merged.rewards, isEmpty);
      expect(merged.hadiths, isEmpty);
    });
  });
}
