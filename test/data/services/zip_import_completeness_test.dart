import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, setUp, setUpAll;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_serializer.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_importer.dart';

// ─── Generators ─────────────────────────────────────────────────────

/// Represents a subset selection of files to include in a ZIP archive.
/// Each boolean indicates whether the corresponding file is present.
class FileSubset {
  final bool hasSeries;
  final bool hasBooks;
  final bool hasRewards;
  final bool hasHadiths;
  final int contentFileCount; // 0–3 content files to include

  const FileSubset({
    required this.hasSeries,
    required this.hasBooks,
    required this.hasRewards,
    required this.hasHadiths,
    required this.contentFileCount,
  });

  @override
  String toString() =>
      'FileSubset(series=$hasSeries, books=$hasBooks, rewards=$hasRewards, '
      'hadiths=$hasHadiths, contentFiles=$contentFileCount)';
}

extension ImportCompletenessGenerators on Any {
  /// Generates a random [FileSubset] representing which files to include.
  Generator<FileSubset> get fileSubset => combine5(
        any.bool,
        any.bool,
        any.bool,
        any.bool,
        any.intInRange(0, 4),
        (bool s, bool b, bool r, bool h, int c) => FileSubset(
          hasSeries: s,
          hasBooks: b,
          hasRewards: r,
          hasHadiths: h,
          contentFileCount: c,
        ),
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

/// Creates valid serialized JSON content for each file type.
class _TestContent {
  static final _serializer = JsonSerializer();

  static final series = [
    SeriesModel(
      id: 1,
      name: 'Test Serisi',
      sortOrder: 1,
      isLocked: false,
      iconEmoji: '📖',
    ),
  ];

  static final books = [
    BookModel(
      id: 1,
      title: 'Test Kitabı',
      description: 'Açıklama',
      assetImage: 'assets/images/book_1/book_1.png',
      bookOrder: 1,
      seriesId: 1,
      contentFile: 'book_1.json',
    ),
    BookModel(
      id: 2,
      title: 'Test Kitabı 2',
      description: 'Açıklama 2',
      assetImage: 'assets/images/book_2/book_2.png',
      bookOrder: 2,
      seriesId: 1,
      contentFile: 'book_2.json',
    ),
    BookModel(
      id: 3,
      title: 'Test Kitabı 3',
      description: 'Açıklama 3',
      assetImage: 'assets/images/book_3/book_3.png',
      bookOrder: 3,
      seriesId: 1,
      contentFile: 'book_3.json',
    ),
  ];

  static final rewards = [
    RewardModel(
      title: 'Ödül',
      description: 'Tebrikler',
      assetImage: 'assets/images/rewards/reward.webp',
      unlockBookId: 1,
    ),
  ];

  static const hadiths = [
    HadithModel(text: 'Kolaylaştırınız', source: 'Buhari'),
  ];

  static List<LevelModel> levelsForBook(int bookId) => [
        LevelModel(
          id: bookId,
          bookId: bookId,
          categoryName: 'Kategori',
          levelOrder: 1,
          title: 'Seviye 1',
          unlockScore: 0,
          assetImage: 'assets/images/book_$bookId/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Kitap $bookId Soru ${i + 1}?',
              optionA: 'A cevabı',
              optionB: 'B cevabı',
              optionC: 'C cevabı',
              optionD: 'D cevabı',
              correctOption: ['A', 'B', 'C', 'D'][i % 4],
              explanation: 'Açıklama',
              type: 'multiple_choice',
            ),
          ),
        ),
      ];

  static String get seriesJson => _serializer.serializeSeries(series);
  static String get booksJson => _serializer.serializeBooks(books);
  static String get rewardsJson => _serializer.serializeRewards(rewards);
  static String get hadithsJson => _serializer.serializeHadiths(hadiths);

  static String contentFileJson(int bookId) =>
      _serializer.serializeContentFile(levelsForBook(bookId));
}

/// Creates a ZIP archive containing only the files specified by [subset].
Uint8List createZipFromSubset(FileSubset subset) {
  final archive = Archive();

  if (subset.hasSeries) {
    archive.add(ArchiveFile.string('series.json', _TestContent.seriesJson));
  }
  if (subset.hasBooks) {
    archive.add(ArchiveFile.string('books.json', _TestContent.booksJson));
  }
  if (subset.hasRewards) {
    archive.add(ArchiveFile.string('rewards.json', _TestContent.rewardsJson));
  }
  if (subset.hasHadiths) {
    archive.add(ArchiveFile.string('hadiths.json', _TestContent.hadithsJson));
  }

  // Add content files (book_1.json, book_2.json, book_3.json) up to count
  for (var i = 1; i <= subset.contentFileCount; i++) {
    archive.add(ArchiveFile.string(
      'content/book_$i.json',
      _TestContent.contentFileJson(i),
    ));
  }

  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

// ─── Tests ──────────────────────────────────────────────────────────

void main() {
  late ZipImporter importer;

  setUp(() {
    importer = ZipImporter();
  });

  group('Property 16: Import Completeness Reporting', () {
    Glados(any.fileSubset, ExploreConfig(numRuns: 100)).test(
      'loaded files + reported-missing files = full expected set of top-level files',
      (subset) {
        final zipBytes = createZipFromSubset(subset);
        final (state, issues) = importer.importZip(zipBytes);

        // The full expected set of top-level files
        const expectedTopLevel = {
          'series.json',
          'books.json',
          'rewards.json',
          'hadiths.json',
        };

        // Determine which top-level files were successfully loaded
        final loadedFiles = <String>{};
        if (state.series.isNotEmpty) loadedFiles.add('series.json');
        if (state.books.isNotEmpty) loadedFiles.add('books.json');
        if (state.rewards.isNotEmpty) loadedFiles.add('rewards.json');
        if (state.hadiths.isNotEmpty) loadedFiles.add('hadiths.json');

        // Determine which files were reported as missing (warning-level issues)
        final reportedMissing = issues
            .where((i) =>
                i.severity == ImportIssueSeverity.warning &&
                i.message.contains('not found'))
            .map((i) => i.fileName)
            .toSet();

        // Property: loaded + missing = full expected set
        final combined = {...loadedFiles, ...reportedMissing};

        expect(
          combined,
          equals(expectedTopLevel),
          reason:
              'The union of loaded files ($loadedFiles) and reported-missing '
              'files ($reportedMissing) must equal the full expected set '
              '($expectedTopLevel). Subset: $subset',
        );
      },
    );

    Glados(any.fileSubset, ExploreConfig(numRuns: 100)).test(
      'loaded files and reported-missing files are disjoint sets',
      (subset) {
        final zipBytes = createZipFromSubset(subset);
        final (state, issues) = importer.importZip(zipBytes);

        // Determine which top-level files were successfully loaded
        final loadedFiles = <String>{};
        if (state.series.isNotEmpty) loadedFiles.add('series.json');
        if (state.books.isNotEmpty) loadedFiles.add('books.json');
        if (state.rewards.isNotEmpty) loadedFiles.add('rewards.json');
        if (state.hadiths.isNotEmpty) loadedFiles.add('hadiths.json');

        // Determine which files were reported as missing
        final reportedMissing = issues
            .where((i) =>
                i.severity == ImportIssueSeverity.warning &&
                i.message.contains('not found'))
            .map((i) => i.fileName)
            .toSet();

        // Property: loaded and missing must be disjoint
        final intersection = loadedFiles.intersection(reportedMissing);

        expect(
          intersection,
          isEmpty,
          reason:
              'A file cannot be both loaded and reported as missing. '
              'Intersection: $intersection. Subset: $subset',
        );
      },
    );

    Glados(any.fileSubset, ExploreConfig(numRuns: 100)).test(
      'content files present in ZIP are loaded into contentFiles map',
      (subset) {
        final zipBytes = createZipFromSubset(subset);
        final (state, issues) = importer.importZip(zipBytes);

        // Expected content file names based on subset
        final expectedContentFiles = <String>{};
        for (var i = 1; i <= subset.contentFileCount; i++) {
          expectedContentFiles.add('book_$i.json');
        }

        // Loaded content files
        final loadedContentFiles = state.contentFiles.keys.toSet();

        // All provided content files should be loaded (no parse errors in valid JSON)
        expect(
          loadedContentFiles,
          equals(expectedContentFiles),
          reason:
              'All content files present in ZIP should be loaded. '
              'Expected: $expectedContentFiles, Got: $loadedContentFiles. '
              'Subset: $subset',
        );
      },
    );

    Glados(any.fileSubset, ExploreConfig(numRuns: 100)).test(
      'number of missing-file warnings equals number of absent top-level files',
      (subset) {
        final zipBytes = createZipFromSubset(subset);
        final (_, issues) = importer.importZip(zipBytes);

        // Count how many top-level files are absent
        var absentCount = 0;
        if (!subset.hasSeries) absentCount++;
        if (!subset.hasBooks) absentCount++;
        if (!subset.hasRewards) absentCount++;
        if (!subset.hasHadiths) absentCount++;

        // Count missing-file warnings
        final missingWarnings = issues
            .where((i) =>
                i.severity == ImportIssueSeverity.warning &&
                i.message.contains('not found'))
            .length;

        expect(
          missingWarnings,
          equals(absentCount),
          reason:
              'Number of missing-file warnings ($missingWarnings) must equal '
              'number of absent top-level files ($absentCount). Subset: $subset',
        );
      },
    );

    Glados(any.fileSubset, ExploreConfig(numRuns: 100)).test(
      'no error-level issues when all provided files contain valid JSON',
      (subset) {
        final zipBytes = createZipFromSubset(subset);
        final (_, issues) = importer.importZip(zipBytes);

        // Since all files in our test ZIP contain valid JSON,
        // there should be no error-level issues
        final errors = issues
            .where((i) => i.severity == ImportIssueSeverity.error)
            .toList();

        expect(
          errors,
          isEmpty,
          reason:
              'No error-level issues should be reported when all provided '
              'files contain valid JSON. Got errors: $errors. Subset: $subset',
        );
      },
    );
  });
}
