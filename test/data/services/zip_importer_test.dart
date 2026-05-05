import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_importer.dart';

/// Helper to create a ZIP archive in memory with the given file entries.
Uint8List createTestZip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

const _validSeriesJson = '''
[
  {
    "id": 1,
    "name": "Siyer-i Nebi",
    "sort_order": 1,
    "is_locked": false,
    "icon_emoji": "🕌",
    "description": "Peygamber Efendimiz"
  }
]
''';

const _validBooksJson = '''
[
  {
    "id": 1,
    "title": "Mekke Dönemi",
    "description": "İslam güneşinin doğuşu.",
    "asset_image": "assets/images/book_1/book_1.png",
    "book_order": 1,
    "series_id": 1,
    "content_file": "book_1.json"
  }
]
''';

const _validRewardsJson = '''
[
  {
    "title": "İlim Talebesi",
    "description": "Tebrikler!",
    "asset_image": "assets/images/rewards/book_1_reward.webp",
    "unlock_book_id": 1
  }
]
''';

const _validHadithsJson = '''
[
  {
    "text": "Kolaylaştırınız, zorlaştırmayınız.",
    "source": "Buhari, İlim, 11"
  }
]
''';

const _validContentJson = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Siyer-i Nebi",
      "level_order": 1,
      "title": "Doğuş ve Çocukluk",
      "unlock_score": 0,
      "asset_image": "assets/images/book_1/level_1.webp",
      "questions": [
        {
          "question_text": "Peygamberimiz nerede doğmuştur?",
          "option_a": "Mekke",
          "option_b": "Medine",
          "option_c": "Taif",
          "option_d": "Şam",
          "correct_option": "A",
          "explanation": "571 yılında Mekke'de doğmuştur.",
          "type": "multiple_choice"
        }
      ]
    }
  ]
}
''';

void main() {
  late ZipImporter importer;

  setUp(() {
    importer = ZipImporter();
  });

  group('importZip', () {
    test('imports a valid ZIP with all files', () {
      final zipBytes = createTestZip({
        'series.json': _validSeriesJson,
        'books.json': _validBooksJson,
        'rewards.json': _validRewardsJson,
        'hadiths.json': _validHadithsJson,
        'content/book_1.json': _validContentJson,
      });

      final (state, issues) = importer.importZip(zipBytes);

      expect(issues, isEmpty);
      expect(state.series.length, 1);
      expect(state.series[0].name, 'Siyer-i Nebi');
      expect(state.books.length, 1);
      expect(state.books[0].title, 'Mekke Dönemi');
      expect(state.rewards.length, 1);
      expect(state.rewards[0].title, 'İlim Talebesi');
      expect(state.hadiths.length, 1);
      expect(state.hadiths[0].text, 'Kolaylaştırınız, zorlaştırmayınız.');
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);
      expect(state.contentFiles['book_1.json']!.length, 1);
      expect(state.contentFiles['book_1.json']![0].title, 'Doğuş ve Çocukluk');
    });

    test('imports ZIP with multiple content files', () {
      const contentJson2 = '''
{
  "levels": [
    {
      "id": 2,
      "book_id": 2,
      "category_name": "Medine",
      "level_order": 1,
      "title": "Hicret",
      "unlock_score": 0,
      "asset_image": null,
      "questions": []
    }
  ]
}
''';

      final zipBytes = createTestZip({
        'series.json': _validSeriesJson,
        'books.json': _validBooksJson,
        'rewards.json': _validRewardsJson,
        'hadiths.json': _validHadithsJson,
        'content/book_1.json': _validContentJson,
        'content/book_2.json': contentJson2,
      });

      final (state, issues) = importer.importZip(zipBytes);

      expect(issues, isEmpty);
      expect(state.contentFiles.length, 2);
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);
      expect(state.contentFiles.containsKey('book_2.json'), isTrue);
      expect(state.contentFiles['book_2.json']![0].title, 'Hicret');
    });

    test('reports warnings for missing files', () {
      // ZIP with only series.json — missing books, rewards, hadiths
      final zipBytes = createTestZip({
        'series.json': _validSeriesJson,
      });

      final (state, issues) = importer.importZip(zipBytes);

      expect(state.series.length, 1);
      expect(state.books, isEmpty);
      expect(state.rewards, isEmpty);
      expect(state.hadiths, isEmpty);

      // Should have warnings for missing files
      final warnings = issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(warnings.length, 3);
      expect(
        warnings.map((w) => w.fileName).toSet(),
        containsAll(['books.json', 'rewards.json', 'hadiths.json']),
      );
    });

    test('reports all four missing files when ZIP has only content', () {
      final zipBytes = createTestZip({
        'content/book_1.json': _validContentJson,
      });

      final (state, issues) = importer.importZip(zipBytes);

      expect(state.contentFiles.containsKey('book_1.json'), isTrue);

      final warnings = issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(warnings.length, 4);
      expect(
        warnings.map((w) => w.fileName).toSet(),
        containsAll(
            ['series.json', 'books.json', 'rewards.json', 'hadiths.json']),
      );
    });

    test('reports error for invalid JSON and continues with other files', () {
      final zipBytes = createTestZip({
        'series.json': 'not valid json!!!',
        'books.json': _validBooksJson,
        'rewards.json': _validRewardsJson,
        'hadiths.json': _validHadithsJson,
        'content/book_1.json': _validContentJson,
      });

      final (state, issues) = importer.importZip(zipBytes);

      // series should be empty due to parse error
      expect(state.series, isEmpty);
      // other files should still be parsed
      expect(state.books.length, 1);
      expect(state.rewards.length, 1);
      expect(state.hadiths.length, 1);
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);

      // Should have an error for series.json
      final errors = issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      expect(errors.length, 1);
      expect(errors[0].fileName, 'series.json');
      expect(errors[0].message, contains('Parse error'));
    });

    test('reports error for invalid content file JSON', () {
      final zipBytes = createTestZip({
        'series.json': _validSeriesJson,
        'books.json': _validBooksJson,
        'rewards.json': _validRewardsJson,
        'hadiths.json': _validHadithsJson,
        'content/book_1.json': '{invalid content}',
      });

      final (state, issues) = importer.importZip(zipBytes);

      expect(state.series.length, 1);
      expect(state.books.length, 1);
      expect(state.contentFiles, isEmpty);

      final errors = issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      expect(errors.length, 1);
      expect(errors[0].fileName, 'content/book_1.json');
      expect(errors[0].message, contains('Parse error'));
    });

    test('reports error for invalid ZIP data', () {
      // Use bytes that are clearly not a valid ZIP (random binary)
      final invalidZipBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8]);

      final (state, issues) = importer.importZip(invalidZipBytes);

      // The archive package may throw or return empty archive.
      // Either way, we should get issues reported.
      expect(issues, isNotEmpty);

      // If it threw, we get a single error about invalid ZIP.
      // If it didn't throw, we get warnings about missing files.
      final hasArchiveError = issues.any(
        (i) =>
            i.severity == ImportIssueSeverity.error &&
            i.message.contains('not a valid ZIP archive'),
      );
      final hasMissingFileWarnings = issues.any(
        (i) => i.severity == ImportIssueSeverity.warning,
      );

      expect(hasArchiveError || hasMissingFileWarnings, isTrue);
    });

    test('strips content/ prefix from content file keys', () {
      final zipBytes = createTestZip({
        'series.json': _validSeriesJson,
        'books.json': _validBooksJson,
        'rewards.json': _validRewardsJson,
        'hadiths.json': _validHadithsJson,
        'content/book_1.json': _validContentJson,
      });

      final (state, _) = importer.importZip(zipBytes);

      // Key should be "book_1.json" not "content/book_1.json"
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);
      expect(state.contentFiles.containsKey('content/book_1.json'), isFalse);
    });

    test('handles empty ZIP archive', () {
      final zipBytes = createTestZip({});

      final (state, issues) = importer.importZip(zipBytes);

      expect(state.series, isEmpty);
      expect(state.books, isEmpty);
      expect(state.rewards, isEmpty);
      expect(state.hadiths, isEmpty);
      expect(state.contentFiles, isEmpty);

      // All four expected files should be reported as missing
      final warnings = issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(warnings.length, 4);
    });
  });

  group('importFiles', () {
    test('imports recognized filenames correctly', () {
      final files = <String, Uint8List>{
        'series.json': Uint8List.fromList(utf8.encode(_validSeriesJson)),
        'books.json': Uint8List.fromList(utf8.encode(_validBooksJson)),
        'rewards.json': Uint8List.fromList(utf8.encode(_validRewardsJson)),
        'hadiths.json': Uint8List.fromList(utf8.encode(_validHadithsJson)),
      };

      final (state, issues) = importer.importFiles(files);

      expect(issues, isEmpty);
      expect(state.series.length, 1);
      expect(state.books.length, 1);
      expect(state.rewards.length, 1);
      expect(state.hadiths.length, 1);
    });

    test('imports book_*.json files as content files', () {
      final files = <String, Uint8List>{
        'book_1.json': Uint8List.fromList(utf8.encode(_validContentJson)),
      };

      final (state, issues) = importer.importFiles(files);

      expect(issues, isEmpty);
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);
      expect(state.contentFiles['book_1.json']!.length, 1);
    });

    test('imports book_*.json with various names', () {
      final files = <String, Uint8List>{
        'book_42.json': Uint8List.fromList(utf8.encode(_validContentJson)),
        'book_abc.json': Uint8List.fromList(utf8.encode(_validContentJson)),
      };

      final (state, issues) = importer.importFiles(files);

      expect(issues, isEmpty);
      expect(state.contentFiles.length, 2);
      expect(state.contentFiles.containsKey('book_42.json'), isTrue);
      expect(state.contentFiles.containsKey('book_abc.json'), isTrue);
    });

    test('reports warnings for unrecognized filenames', () {
      final files = <String, Uint8List>{
        'series.json': Uint8List.fromList(utf8.encode(_validSeriesJson)),
        'unknown_file.json': Uint8List.fromList(utf8.encode('[]')),
        'readme.txt': Uint8List.fromList(utf8.encode('hello')),
      };

      final (state, issues) = importer.importFiles(files);

      expect(state.series.length, 1);

      final warnings = issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(warnings.length, 2);
      expect(
        warnings.map((w) => w.fileName).toSet(),
        containsAll(['unknown_file.json', 'readme.txt']),
      );
    });

    test('reports error for invalid JSON in recognized file', () {
      final files = <String, Uint8List>{
        'series.json': Uint8List.fromList(utf8.encode('invalid json')),
        'books.json': Uint8List.fromList(utf8.encode(_validBooksJson)),
      };

      final (state, issues) = importer.importFiles(files);

      expect(state.series, isEmpty);
      expect(state.books.length, 1);

      final errors = issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      expect(errors.length, 1);
      expect(errors[0].fileName, 'series.json');
      expect(errors[0].message, contains('Parse error'));
    });

    test('reports error for invalid JSON in content file', () {
      final files = <String, Uint8List>{
        'book_1.json': Uint8List.fromList(utf8.encode('not json')),
      };

      final (state, issues) = importer.importFiles(files);

      expect(state.contentFiles, isEmpty);

      final errors = issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      expect(errors.length, 1);
      expect(errors[0].fileName, 'book_1.json');
      expect(errors[0].message, contains('Parse error'));
    });

    test('handles empty file map', () {
      final (state, issues) = importer.importFiles({});

      expect(state, ContentState.empty());
      expect(issues, isEmpty);
    });

    test('handles mix of valid, invalid, and unrecognized files', () {
      final files = <String, Uint8List>{
        'series.json': Uint8List.fromList(utf8.encode(_validSeriesJson)),
        'books.json': Uint8List.fromList(utf8.encode('bad json')),
        'rewards.json': Uint8List.fromList(utf8.encode(_validRewardsJson)),
        'hadiths.json': Uint8List.fromList(utf8.encode(_validHadithsJson)),
        'book_1.json': Uint8List.fromList(utf8.encode(_validContentJson)),
        'random.csv': Uint8List.fromList(utf8.encode('a,b,c')),
      };

      final (state, issues) = importer.importFiles(files);

      // Valid files should be parsed
      expect(state.series.length, 1);
      expect(state.rewards.length, 1);
      expect(state.hadiths.length, 1);
      expect(state.contentFiles.containsKey('book_1.json'), isTrue);

      // books.json should fail
      expect(state.books, isEmpty);

      // Should have 1 error (books.json) and 1 warning (random.csv)
      final errors = issues
          .where((i) => i.severity == ImportIssueSeverity.error)
          .toList();
      final warnings = issues
          .where((i) => i.severity == ImportIssueSeverity.warning)
          .toList();
      expect(errors.length, 1);
      expect(errors[0].fileName, 'books.json');
      expect(warnings.length, 1);
      expect(warnings[0].fileName, 'random.csv');
    });
  });

  group('ImportIssue', () {
    test('equality works correctly', () {
      const issue1 = ImportIssue(
        fileName: 'test.json',
        message: 'error',
        severity: ImportIssueSeverity.error,
      );
      const issue2 = ImportIssue(
        fileName: 'test.json',
        message: 'error',
        severity: ImportIssueSeverity.error,
      );
      const issue3 = ImportIssue(
        fileName: 'test.json',
        message: 'different',
        severity: ImportIssueSeverity.error,
      );

      expect(issue1, equals(issue2));
      expect(issue1, isNot(equals(issue3)));
    });

    test('toString provides useful output', () {
      const issue = ImportIssue(
        fileName: 'series.json',
        message: 'File not found',
        severity: ImportIssueSeverity.warning,
      );

      expect(issue.toString(), contains('warning'));
      expect(issue.toString(), contains('series.json'));
      expect(issue.toString(), contains('File not found'));
    });
  });
}
