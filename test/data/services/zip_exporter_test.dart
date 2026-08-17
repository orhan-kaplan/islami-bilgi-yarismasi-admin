import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_exporter.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_importer.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

/// Creates a valid ContentState that passes all validation rules.
ContentState _createValidState() {
  return ContentState(
    series: [
      const SeriesModel(
        id: 1,
        name: 'Siyer-i Nebi',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
        description: 'Peygamber Efendimiz',
      ),
    ],
    books: [
      const BookModel(
        id: 1,
        title: 'Mekke Dönemi',
        description: 'İslam güneşinin doğuşu.',
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
          categoryName: 'Siyer-i Nebi',
          levelOrder: 1,
          title: 'Doğuş ve Çocukluk',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Soru ${i + 1}: Peygamberimiz hakkında?',
              optionA: 'Cevap A',
              optionB: 'Cevap B',
              optionC: 'Cevap C',
              optionD: 'Cevap D',
              correctOption: 'A',
              explanation: 'Açıklama ${i + 1}',
              type: 'multiple_choice',
            ),
          ),
        ),
      ],
    },
    rewards: [
      const RewardModel(
        title: 'İlim Talebesi',
        description: 'Tebrikler!',
        assetImage: 'assets/images/rewards/book_1_reward.webp',
        unlockBookId: 1,
      ),
    ],
    hadiths: [
      const HadithModel(
        text: 'Kolaylaştırınız, zorlaştırmayınız.',
        source: 'Buhari, İlim, 11',
      ),
    ],
  );
}

/// Creates a valid state with multiple books/content files.
ContentState _createMultiBookState() {
  return ContentState(
    series: [
      const SeriesModel(
        id: 1,
        name: 'Siyer-i Nebi',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
        description: null,
      ),
    ],
    books: [
      const BookModel(
        id: 1,
        title: 'Mekke Dönemi',
        description: 'İslam güneşinin doğuşu.',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
      const BookModel(
        id: 2,
        title: 'Medine Dönemi',
        description: 'Hicret sonrası.',
        assetImage: 'assets/images/book_2/book_2.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_2.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [
        LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Siyer-i Nebi',
          levelOrder: 1,
          title: 'Doğuş ve Çocukluk',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Kitap 1 Soru ${i + 1}?',
              optionA: 'A',
              optionB: 'B',
              optionC: 'C',
              optionD: 'D',
              correctOption: ['A', 'B', 'C', 'D'][i % 4],
              explanation: 'Açıklama',
              type: 'multiple_choice',
            ),
          ),
        ),
      ],
      'book_2.json': [
        LevelModel(
          id: 2,
          bookId: 2,
          categoryName: 'Medine',
          levelOrder: 1,
          title: 'Hicret',
          unlockScore: 0,
          assetImage: 'assets/images/book_2/level_1.webp',
          questions: List.generate(
            10,
            (i) => QuestionModel(
              questionText: 'Kitap 2 Soru ${i + 1}?',
              optionA: 'A',
              optionB: 'B',
              optionC: 'C',
              optionD: 'D',
              correctOption: ['A', 'B', 'C', 'D'][i % 4],
              explanation: 'Açıklama',
              type: 'multiple_choice',
            ),
          ),
        ),
      ],
    },
    rewards: [
      const RewardModel(
        title: 'İlim Talebesi',
        description: 'Tebrikler!',
        assetImage: 'assets/images/rewards/book_1_reward.webp',
        unlockBookId: 1,
      ),
      const RewardModel(
        title: 'Alim',
        description: 'Harika!',
        assetImage: 'assets/images/rewards/book_2_reward.webp',
        unlockBookId: 2,
      ),
    ],
    hadiths: [
      const HadithModel(
        text: 'Kolaylaştırınız, zorlaştırmayınız.',
        source: 'Buhari, İlim, 11',
      ),
    ],
  );
}

void main() {
  late ZipExporter exporter;

  setUp(() {
    exporter = ZipExporter();
  });

  group('ZipExporter - exportZip', () {
    test('exports a valid state and produces a ZIP with correct structure', () {
      final state = _createValidState();
      final zipBytes = exporter.exportZip(state);

      // Decode the ZIP and check structure
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final fileNames = archive.files.map((f) => f.name).toSet();

      expect(fileNames, contains('series.json'));
      expect(fileNames, contains('books.json'));
      expect(fileNames, contains('rewards.json'));
      expect(fileNames, contains('hadiths.json'));
      expect(fileNames, contains('content/book_1.json'));
    });

    test('ZIP contains all expected files for multi-book state', () {
      final state = _createMultiBookState();
      final zipBytes = exporter.exportZip(state);

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final fileNames = archive.files.map((f) => f.name).toSet();

      // Top-level files
      expect(fileNames, contains('series.json'));
      expect(fileNames, contains('books.json'));
      expect(fileNames, contains('rewards.json'));
      expect(fileNames, contains('hadiths.json'));

      // Content files
      expect(fileNames, contains('content/book_1.json'));
      expect(fileNames, contains('content/book_2.json'));

      // Total file count: 4 top-level + 2 content = 6
      expect(archive.files.where((f) => f.isFile).length, 6);
    });

    test('ZIP file contents are valid JSON', () {
      final state = _createValidState();
      final zipBytes = exporter.exportZip(state);

      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final content = utf8.decode(file.content as List<int>);
          // Should not throw
          expect(() => json.decode(content), returnsNormally,
              reason: '${file.name} should contain valid JSON');
        }
      }
    });

    test('series.json contains correct data', () {
      final state = _createValidState();
      final zipBytes = exporter.exportZip(state);

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final seriesFile =
          archive.files.firstWhere((f) => f.name == 'series.json');
      final content = utf8.decode(seriesFile.content as List<int>);
      final decoded = json.decode(content) as List;

      expect(decoded.length, 1);
      expect(decoded[0]['name'], 'Siyer-i Nebi');
      expect(decoded[0]['id'], 1);
      expect(decoded[0]['icon_emoji'], '🕌');
    });

    test('content files are placed under content/ directory', () {
      final state = _createValidState();
      final zipBytes = exporter.exportZip(state);

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final contentFiles =
          archive.files.where((f) => f.name.startsWith('content/')).toList();

      expect(contentFiles.length, 1);
      expect(contentFiles[0].name, 'content/book_1.json');

      // Verify content file structure
      final content = utf8.decode(contentFiles[0].content as List<int>);
      final decoded = json.decode(content) as Map<String, dynamic>;
      expect(decoded.containsKey('levels'), isTrue);
      expect((decoded['levels'] as List).length, 1);
    });

    test('throws ValidationBlockedExportException when validation errors exist',
        () {
      // Create a state with a validation error: book references non-existent series
      final invalidState = ContentState(
        series: [
          const SeriesModel(
            id: 1,
            name: 'Test',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📚',
            description: null,
          ),
        ],
        books: [
          const BookModel(
            id: 1,
            title: 'Test Book',
            description: 'Desc',
            assetImage: 'assets/images/book.png',
            bookOrder: 1,
            seriesId: 999, // Non-existent series!
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {
          'book_1.json': [
            LevelModel(
              id: 1,
              bookId: 1,
              categoryName: 'Test',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 0,
              assetImage: null,
              questions: List.generate(
                10,
                (i) => QuestionModel(
                  questionText: 'Q${i + 1}?',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: 'A',
                  explanation: 'E',
                  type: 'multiple_choice',
                ),
              ),
            ),
          ],
        },
        rewards: [],
        hadiths: [],
      );

      expect(
        () => exporter.exportZip(invalidState),
        throwsA(isA<ValidationBlockedExportException>()),
      );

      try {
        exporter.exportZip(invalidState);
      } on ValidationBlockedExportException catch (e) {
        expect(e.errors, isNotEmpty);
        expect(
          e.errors.every((i) => i.severity == ValidationSeverity.error),
          isTrue,
        );
      }
    });

    test('warnings do NOT block export', () {
      // Create a state that has warnings (< 10 questions) but no errors
      const stateWithWarnings = ContentState(
        series: [
          SeriesModel(
            id: 1,
            name: 'Test',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📚',
            description: null,
          ),
        ],
        books: [
          BookModel(
            id: 1,
            title: 'Test Book',
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
              categoryName: 'Test',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 0,
              assetImage: null,
              // Only 3 questions — triggers warning but not error
              questions: [
                QuestionModel(
                  questionText: 'Q1?',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: 'A',
                  explanation: null,
                  type: 'multiple_choice',
                ),
                QuestionModel(
                  questionText: 'Q2?',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: 'B',
                  explanation: null,
                  type: 'multiple_choice',
                ),
                QuestionModel(
                  questionText: 'Q3?',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: 'C',
                  explanation: null,
                  type: 'multiple_choice',
                ),
              ],
            ),
          ],
        },
        rewards: [],
        hadiths: [],
      );

      // Verify there ARE warnings
      final issues = ContentValidator().validateAll(stateWithWarnings);
      final warnings =
          issues.where((i) => i.severity == ValidationSeverity.warning).toList();
      expect(warnings, isNotEmpty, reason: 'State should have warnings');

      // But export should still succeed
      final zipBytes = exporter.exportZip(stateWithWarnings);
      expect(zipBytes, isNotEmpty);

      // Verify it's a valid ZIP
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive.files, isNotEmpty);
    });

    test('round-trip: export then import produces equivalent state', () {
      final originalState = _createValidState();

      // Export
      final zipBytes = exporter.exportZip(originalState);

      // Import
      final importer = ZipImporter();
      final (importedState, issues) = importer.importZip(zipBytes);

      expect(issues, isEmpty);

      // Compare states
      expect(importedState.series.length, originalState.series.length);
      expect(importedState.books.length, originalState.books.length);
      expect(importedState.rewards.length, originalState.rewards.length);
      expect(importedState.hadiths.length, originalState.hadiths.length);
      expect(
          importedState.contentFiles.length, originalState.contentFiles.length);

      // Verify series data
      expect(importedState.series[0].id, originalState.series[0].id);
      expect(importedState.series[0].name, originalState.series[0].name);
      expect(importedState.series[0].iconEmoji,
          originalState.series[0].iconEmoji);

      // Verify books data
      expect(importedState.books[0].id, originalState.books[0].id);
      expect(importedState.books[0].title, originalState.books[0].title);
      expect(importedState.books[0].contentFile,
          originalState.books[0].contentFile);

      // Verify content files
      expect(importedState.contentFiles.containsKey('book_1.json'), isTrue);
      final importedLevels = importedState.contentFiles['book_1.json']!;
      final originalLevels = originalState.contentFiles['book_1.json']!;
      expect(importedLevels.length, originalLevels.length);
      expect(importedLevels[0].title, originalLevels[0].title);
      expect(importedLevels[0].questions.length,
          originalLevels[0].questions.length);
      expect(importedLevels[0].questions[0].questionText,
          originalLevels[0].questions[0].questionText);

      // Verify rewards
      expect(importedState.rewards[0].title, originalState.rewards[0].title);

      // Verify hadiths
      expect(importedState.hadiths[0].text, originalState.hadiths[0].text);
      expect(importedState.hadiths[0].source, originalState.hadiths[0].source);
    });

    test('round-trip with multi-book state preserves all content', () {
      final originalState = _createMultiBookState();

      // Export
      final zipBytes = exporter.exportZip(originalState);

      // Import
      final importer = ZipImporter();
      final (importedState, issues) = importer.importZip(zipBytes);

      expect(issues, isEmpty);

      // Verify all content files are preserved
      expect(importedState.contentFiles.length, 2);
      expect(importedState.contentFiles.containsKey('book_1.json'), isTrue);
      expect(importedState.contentFiles.containsKey('book_2.json'), isTrue);

      // Verify book 2 content
      final book2Levels = importedState.contentFiles['book_2.json']!;
      expect(book2Levels.length, 1);
      expect(book2Levels[0].title, 'Hicret');
      expect(book2Levels[0].bookId, 2);
    });
  });

  group('ValidationBlockedExportException', () {
    test('contains the error list', () {
      const errors = [
        ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: r'$[0].series_id',
          message: 'Non-existent series',
        ),
      ];

      const exception = ValidationBlockedExportException(errors);

      expect(exception.errors, equals(errors));
      expect(exception.errors.length, 1);
    });

    test('toString provides useful output', () {
      const errors = [
        ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: r'$[0].series_id',
          message: 'Non-existent series',
        ),
        ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: r'$[0].id',
          message: 'Duplicate ID',
        ),
      ];

      const exception = ValidationBlockedExportException(errors);

      expect(exception.toString(), contains('2 error(s)'));
      expect(exception.toString(), contains('ValidationBlockedExportException'));
    });
  });

  group('ZIP sidecar extras', () {
    test('export without extras omits feedback.json and game_config.json', () {
      final zipBytes = exporter.exportZip(_createValidState());
      final names = ZipDecoder()
          .decodeBytes(zipBytes)
          .files
          .where((f) => f.isFile)
          .map((f) => f.name)
          .toSet();

      expect(names.contains('feedback.json'), isFalse);
      expect(names.contains('game_config.json'), isFalse);
    });

    test('export with extras includes sidecars and importAll roundtrips', () {
      final zipBytes = exporter.exportZip(
        _createValidState(),
        feedback: FeedbackContentState.empty(),
        gameConfig: GameConfigState.defaults,
      );
      final names = ZipDecoder()
          .decodeBytes(zipBytes)
          .files
          .where((f) => f.isFile)
          .map((f) => f.name)
          .toSet();

      expect(names, contains('feedback.json'));
      expect(names, contains('game_config.json'));

      final bundle = ZipImporter().importAll(zipBytes);
      expect(bundle.feedback, isNotNull);
      expect(bundle.gameConfig?.quiz.lives, 3);
      expect(
        bundle.issues.where(
          (i) =>
              i.fileName == 'feedback.json' &&
              i.severity == ImportIssueSeverity.warning,
        ),
        isEmpty,
      );
    });

    test('importAll of old ZIP warns and does not parse extras', () {
      final zipBytes = exporter.exportZip(_createValidState());
      final bundle = ZipImporter().importAll(zipBytes);

      expect(bundle.feedback, isNull);
      expect(bundle.gameConfig, isNull);
      expect(
        bundle.issues.any(
          (i) =>
              i.fileName == 'feedback.json' &&
              i.severity == ImportIssueSeverity.warning,
        ),
        isTrue,
      );
      expect(
        bundle.issues.any(
          (i) =>
              i.fileName == 'game_config.json' &&
              i.severity == ImportIssueSeverity.warning,
        ),
        isTrue,
      );
    });
  });
}
