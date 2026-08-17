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
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_exporter.dart';

/// Generates a valid [ContentState] that passes all validation rules.
///
/// The generator produces states with:
/// - 1–5 books with unique content_file names
/// - Proper sequential ordering (sort_order, book_order, level_order)
/// - Valid foreign key references (book→series, level→book, reward→book)
/// - Valid question types and constraints
/// - Non-empty required fields
/// - Asset images with "assets/" prefix
extension ValidContentStateGenerators on Any {
  /// Generates a non-empty string suitable for required fields.
  Generator<String> get _nonEmptyString => simple(
        generate: (random, size) {
          const chars = 'abcdefghijklmnopqrstuvwxyz';
          final length = random.nextInt(size.clamp(1, 20)) + 3;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(chars[random.nextInt(chars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input.length > 3) {
            yield input.substring(0, input.length ~/ 2 + 2);
          }
        },
      );

  /// Generates a valid content file name like "book_N.json".
  Generator<String> get _contentFileName => simple(
        generate: (random, size) {
          final id = random.nextInt(size.clamp(1, 100)) + 1;
          return 'book_$id.json';
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a book count between 1 and 5.
  Generator<int> get _bookCount => simple(
        generate: (random, size) => random.nextInt(5) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input - 1;
        },
      );

  /// Generates a valid [ContentState] with varying book counts and unique
  /// content_file names. The state satisfies all validation rules so that
  /// [ZipExporter.exportZip] will succeed.
  Generator<ContentState> get validExportableState => combine2(
        _bookCount,
        _nonEmptyString,
        (int numBooks, String baseName) {
          // Create a single series
          final series = [
            SeriesModel(
              id: 1,
              name: 'Seri $baseName',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
              description: null,
            ),
          ];

          // Create books with unique IDs, sequential order, and unique content files
          final books = <BookModel>[];
          final contentFiles = <String, List<LevelModel>>{};

          for (var i = 0; i < numBooks; i++) {
            final bookId = i + 1;
            final contentFile = 'book_$bookId.json';

            books.add(BookModel(
              id: bookId,
              title: 'Kitap ${i + 1}',
              description: 'Açıklama ${i + 1}',
              assetImage: 'assets/images/book_$bookId/book_$bookId.png',
              bookOrder: i + 1,
              seriesId: 1,
              contentFile: contentFile,
            ));

            // Create 1 level per book with 10 questions (avoids low-count warning)
            final options = ['A', 'B', 'C', 'D'];
            final questions = List.generate(
              10,
              (qi) => QuestionModel(
                questionText: 'Kitap $bookId Soru ${qi + 1}?',
                optionA: 'A cevabı',
                optionB: 'B cevabı',
                optionC: 'C cevabı',
                optionD: 'D cevabı',
                correctOption: options[qi % 4],
                explanation: 'Açıklama',
                type: 'multiple_choice',
              ),
            );

            contentFiles[contentFile] = [
              LevelModel(
                id: i + 1, // Unique level IDs across all books
                bookId: bookId,
                categoryName: 'Kategori',
                levelOrder: 1,
                title: 'Seviye 1',
                unlockScore: 0,
                assetImage: 'assets/images/book_$bookId/level_1.webp',
                questions: questions,
              ),
            ];
          }

          // Create rewards referencing valid book IDs
          final rewards = [
            const RewardModel(
              title: 'Ödül',
              description: 'Tebrikler',
              assetImage: 'assets/images/rewards/reward.webp',
              unlockBookId: 1,
            ),
          ];

          // Create hadiths
          final hadiths = [
            const HadithModel(
              text: 'Kolaylaştırınız',
              source: 'Buhari',
            ),
          ];

          return ContentState(
            series: series,
            books: books,
            contentFiles: contentFiles,
            rewards: rewards,
            hadiths: hadiths,
          );
        },
      );

  /// Generates a valid [ContentState] with randomized content_file names
  /// to test that the ZIP structure correctly reflects arbitrary file names.
  Generator<ContentState> get validStateWithRandomContentFiles => combine3(
        _bookCount,
        listWithLengthInRange(1, 5, _contentFileName),
        _nonEmptyString,
        (int numBooks, List<String> fileNames, String baseName) {
          // Ensure unique content file names by deduplicating
          final uniqueFiles = <String>[];
          final seen = <String>{};
          for (final name in fileNames) {
            if (seen.add(name)) {
              uniqueFiles.add(name);
            }
          }
          // Ensure we have at least numBooks unique file names
          final actualBookCount = numBooks.clamp(1, uniqueFiles.length);
          final selectedFiles = uniqueFiles.take(actualBookCount).toList();

          final series = [
            SeriesModel(
              id: 1,
              name: 'Seri $baseName',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '🕌',
              description: null,
            ),
          ];

          final books = <BookModel>[];
          final contentFiles = <String, List<LevelModel>>{};

          for (var i = 0; i < selectedFiles.length; i++) {
            final bookId = i + 1;
            final contentFile = selectedFiles[i];

            books.add(BookModel(
              id: bookId,
              title: 'Kitap ${i + 1}',
              description: 'Açıklama ${i + 1}',
              assetImage: 'assets/images/book_$bookId/book_$bookId.png',
              bookOrder: i + 1,
              seriesId: 1,
              contentFile: contentFile,
            ));

            final options = ['A', 'B', 'C', 'D'];
            final questions = List.generate(
              10,
              (qi) => QuestionModel(
                questionText: 'Kitap $bookId Soru ${qi + 1}?',
                optionA: 'A cevabı',
                optionB: 'B cevabı',
                optionC: 'C cevabı',
                optionD: 'D cevabı',
                correctOption: options[qi % 4],
                explanation: 'Açıklama',
                type: 'multiple_choice',
              ),
            );

            contentFiles[contentFile] = [
              LevelModel(
                id: i + 1,
                bookId: bookId,
                categoryName: 'Kategori',
                levelOrder: 1,
                title: 'Seviye 1',
                unlockScore: 0,
                assetImage: 'assets/images/book_$bookId/level_1.webp',
                questions: questions,
              ),
            ];
          }

          final rewards = [
            const RewardModel(
              title: 'Ödül',
              description: 'Tebrikler',
              assetImage: 'assets/images/rewards/reward.webp',
              unlockBookId: 1,
            ),
          ];

          final hadiths = [
            const HadithModel(
              text: 'Kolaylaştırınız',
              source: 'Buhari',
            ),
          ];

          return ContentState(
            series: series,
            books: books,
            contentFiles: contentFiles,
            rewards: rewards,
            hadiths: hadiths,
          );
        },
      );
}

void main() {
  late ZipExporter exporter;

  setUp(() {
    exporter = ZipExporter();
  });

  group('Property 2: Export ZIP Structure Matches Content File References', () {
    Glados(any.validExportableState, ExploreConfig(numRuns: 100)).test(
      'ZIP contains exactly 4 top-level files plus content files matching book.contentFile',
      (state) {
        // Export should succeed (state is valid)
        final zipBytes = exporter.exportZip(state);

        // Decode the ZIP
        final archive = ZipDecoder().decodeBytes(zipBytes);
        final fileNames =
            archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

        // Expected top-level files
        const expectedTopLevel = {
          'series.json',
          'books.json',
          'rewards.json',
          'hadiths.json',
        };

        // Expected content files: content/{book.contentFile} for each book
        final expectedContentFiles = state.books
            .map((b) => 'content/${b.contentFile}')
            .toSet();

        // The full expected set
        final expectedFiles = {...expectedTopLevel, ...expectedContentFiles};

        // Verify exact match
        expect(
          fileNames,
          equals(expectedFiles),
          reason:
              'ZIP should contain exactly the 4 top-level files and '
              'content files for each book. '
              'Expected: $expectedFiles, Got: $fileNames',
        );
      },
    );

    Glados(any.validStateWithRandomContentFiles, ExploreConfig(numRuns: 100))
        .test(
      'ZIP content/ entries correspond 1:1 with contentFiles map keys',
      (state) {
        final zipBytes = exporter.exportZip(state);

        final archive = ZipDecoder().decodeBytes(zipBytes);
        final contentEntries = archive.files
            .where((f) => f.isFile && f.name.startsWith('content/'))
            .map((f) => f.name.replaceFirst('content/', ''))
            .toSet();

        // The content entries in the ZIP should match the contentFiles map keys
        final expectedContentKeys = state.contentFiles.keys.toSet();

        expect(
          contentEntries,
          equals(expectedContentKeys),
          reason:
              'ZIP content/ entries should match contentFiles map keys exactly. '
              'Expected: $expectedContentKeys, Got: $contentEntries',
        );
      },
    );

    Glados(any.validExportableState, ExploreConfig(numRuns: 100)).test(
      'number of content files in ZIP equals number of books',
      (state) {
        final zipBytes = exporter.exportZip(state);

        final archive = ZipDecoder().decodeBytes(zipBytes);
        final contentFileCount = archive.files
            .where((f) => f.isFile && f.name.startsWith('content/'))
            .length;

        expect(
          contentFileCount,
          equals(state.books.length),
          reason:
              'ZIP should have exactly one content file per book. '
              'Books: ${state.books.length}, Content files: $contentFileCount',
        );
      },
    );

    Glados(any.validExportableState, ExploreConfig(numRuns: 100)).test(
      'total file count in ZIP equals 4 + number of content files',
      (state) {
        final zipBytes = exporter.exportZip(state);

        final archive = ZipDecoder().decodeBytes(zipBytes);
        final totalFiles = archive.files.where((f) => f.isFile).length;

        // 4 top-level (series, books, rewards, hadiths) + content files
        final expectedTotal = 4 + state.contentFiles.length;

        expect(
          totalFiles,
          equals(expectedTotal),
          reason:
              'ZIP should contain exactly 4 top-level + ${state.contentFiles.length} '
              'content files = $expectedTotal total. Got: $totalFiles',
        );
      },
    );
  });
}
