import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, setUp, setUpAll;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_exporter.dart';

// ─── Generators ─────────────────────────────────────────────────────

/// Enum representing different ways to introduce an ERROR-level validation issue.
enum ErrorInjection {
  /// Book references a non-existent series_id.
  brokenSeriesFK,

  /// Level references a non-existent book_id.
  brokenBookFK,

  /// Duplicate series IDs.
  duplicateSeriesId,

  /// Duplicate book IDs.
  duplicateBookId,

  /// Non-sequential sort_order in series.
  nonSequentialOrder,

  /// Invalid correct_option value (not A/B/C/D).
  invalidCorrectOption,

  /// Empty required field (book title).
  emptyRequiredField,

  /// Content file references non-existent book.
  contentFileMismatch,
}

extension ExportBlockedGenerators on Any {
  /// Generates a random [ErrorInjection] type.
  Generator<ErrorInjection> get errorInjection => simple(
        generate: (random, size) {
          final values = ErrorInjection.values;
          return values[random.nextInt(values.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a positive integer for IDs.
  Generator<int> get _positiveId => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 100)) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input - 1;
        },
      );

  /// Generates a [ContentState] with at least one ERROR-level validation issue
  /// based on the given [ErrorInjection] type.
  Generator<ContentState> get invalidStateWithError => combine2(
        errorInjection,
        _positiveId,
        (ErrorInjection injection, int seed) {
          switch (injection) {
            case ErrorInjection.brokenSeriesFK:
              return _stateWithBrokenSeriesFK(seed);
            case ErrorInjection.brokenBookFK:
              return _stateWithBrokenBookFK(seed);
            case ErrorInjection.duplicateSeriesId:
              return _stateWithDuplicateSeriesId(seed);
            case ErrorInjection.duplicateBookId:
              return _stateWithDuplicateBookId(seed);
            case ErrorInjection.nonSequentialOrder:
              return _stateWithNonSequentialOrder(seed);
            case ErrorInjection.invalidCorrectOption:
              return _stateWithInvalidCorrectOption(seed);
            case ErrorInjection.emptyRequiredField:
              return _stateWithEmptyRequiredField(seed);
            case ErrorInjection.contentFileMismatch:
              return _stateWithContentFileMismatch(seed);
          }
        },
      );
}

// ─── State Builders with Specific Errors ────────────────────────────

/// Book references series_id that doesn't exist.
ContentState _stateWithBrokenSeriesFK(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 999, // Non-existent series!
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 1, seed)],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Level references book_id that doesn't exist.
ContentState _stateWithBrokenBookFK(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 999, seed)], // book_id 999 doesn't exist
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Two series with the same ID.
ContentState _stateWithDuplicateSeriesId(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri A $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
      SeriesModel(
        id: 1, // Duplicate!
        name: 'Seri B $seed',
        sortOrder: 2,
        isLocked: false,
        iconEmoji: '🕌',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 1, seed)],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Two books with the same ID.
ContentState _stateWithDuplicateBookId(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap A $seed',
        description: 'Açıklama A',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
      BookModel(
        id: 1, // Duplicate!
        title: 'Kitap B $seed',
        description: 'Açıklama B',
        assetImage: 'assets/images/book_2/book_2.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_2.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 1, seed)],
      'book_2.json': [_validLevel(2, 1, seed + 1)],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Series with non-sequential sort_order (e.g., 1, 3 instead of 1, 2).
ContentState _stateWithNonSequentialOrder(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri A $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
      SeriesModel(
        id: 2,
        name: 'Seri B $seed',
        sortOrder: 5, // Non-sequential! Should be 2
        isLocked: false,
        iconEmoji: '🕌',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 1, seed)],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Question with invalid correct_option (not A/B/C/D).
ContentState _stateWithInvalidCorrectOption(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
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
          categoryName: 'Kategori',
          levelOrder: 1,
          title: 'Seviye 1',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Soru ${i + 1} $seed?',
              optionA: 'A cevabı',
              optionB: 'B cevabı',
              optionC: 'C cevabı',
              optionD: 'D cevabı',
              correctOption: i == 0 ? 'X' : 'A', // First question has invalid option
              explanation: 'Açıklama',
              type: 'multiple_choice',
            ),
          ),
        ),
      ],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Book with empty required title field.
ContentState _stateWithEmptyRequiredField(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: '', // Empty required field!
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [_validLevel(1, 1, seed)],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

/// Content file key doesn't match any book's contentFile field.
ContentState _stateWithContentFileMismatch(int seed) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Seri $seed',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Kitap $seed',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      // Content file has levels with book_id that doesn't match the book
      // whose contentFile points here
      'book_1.json': [
        LevelModel(
          id: 1,
          bookId: 999, // Doesn't match book id 1
          categoryName: 'Kategori',
          levelOrder: 1,
          title: 'Seviye 1',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Soru ${i + 1} $seed?',
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
      ],
    },
    rewards: [],
    hadiths: [const HadithModel(text: 'Hadis', source: 'Kaynak')],
  );
}

// ─── Helpers ────────────────────────────────────────────────────────

/// Creates a valid level with 10 multiple-choice questions.
LevelModel _validLevel(int levelId, int bookId, int seed) {
  return LevelModel(
    id: levelId,
    bookId: bookId,
    categoryName: 'Kategori',
    levelOrder: 1,
    title: 'Seviye $levelId',
    unlockScore: 0,
    assetImage: 'assets/images/book_$bookId/level_$levelId.webp',
    questions: List.generate(
      10,
      (i) => QuestionModel(
        questionText: 'Soru ${i + 1} (L$levelId, S$seed)?',
        optionA: 'A cevabı',
        optionB: 'B cevabı',
        optionC: 'C cevabı',
        optionD: 'D cevabı',
        correctOption: ['A', 'B', 'C', 'D'][i % 4],
        explanation: 'Açıklama',
        type: 'multiple_choice',
      ),
    ),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────

void main() {
  late ZipExporter exporter;
  late ContentValidator validator;

  setUp(() {
    exporter = ZipExporter();
    validator = ContentValidator();
  });

  group('Property 3: Export Blocked on Validation Errors', () {
    Glados(any.invalidStateWithError, ExploreConfig(numRuns: 100)).test(
      'exportZip throws ValidationBlockedExportException for states with ERROR-level issues',
      (state) {
        // Precondition: confirm the state actually has at least one ERROR
        final issues = validator.validateAll(state);
        final errors = issues
            .where((i) => i.severity == ValidationSeverity.error)
            .toList();

        expect(
          errors,
          isNotEmpty,
          reason:
              'Generated state must have at least one ERROR-level issue for this property to be meaningful',
        );

        // Property: exportZip must throw and produce no ZIP
        expect(
          () => exporter.exportZip(state),
          throwsA(isA<ValidationBlockedExportException>()),
          reason:
              'exportZip must throw ValidationBlockedExportException when state has validation errors',
        );

        // Verify the exception contains the errors
        try {
          exporter.exportZip(state);
          fail('Should have thrown');
        } on ValidationBlockedExportException catch (e) {
          // All reported errors must be ERROR-level
          expect(
            e.errors.every((i) => i.severity == ValidationSeverity.error),
            isTrue,
            reason: 'Exception should only contain ERROR-level issues',
          );

          // The exception must contain at least one error
          expect(
            e.errors,
            isNotEmpty,
            reason: 'Exception must contain at least one error',
          );
        }
      },
    );

    Glados(any.invalidStateWithError, ExploreConfig(numRuns: 100)).test(
      'no ZIP bytes are produced when validation errors exist',
      (state) {
        // Verify that the function throws before producing any output.
        // Since the function either returns bytes or throws, if it throws
        // then by definition no ZIP was produced.
        Object? caughtError;
        try {
          exporter.exportZip(state);
        } catch (e) {
          caughtError = e;
        }

        expect(
          caughtError,
          isNotNull,
          reason: 'exportZip must throw for invalid states',
        );
        expect(
          caughtError,
          isA<ValidationBlockedExportException>(),
          reason: 'The thrown error must be ValidationBlockedExportException',
        );
      },
    );
  });
}
