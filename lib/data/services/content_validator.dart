import '../../core/constants/validation_rules.dart';
import '../models/content_state.dart';

/// Severity of a validation issue.
enum ValidationSeverity { error, warning }

/// A single validation issue found by [ContentValidator].
class ValidationIssue {
  final ValidationSeverity severity;

  /// The relevant JSON file, e.g. `"series.json"`, `"content/book_1.json"`.
  final String sourceFile;

  /// A JSON-path style locator, e.g. `"$.levels[0].questions[2].correct_option"`.
  final String jsonPath;

  /// Human-readable description of the problem.
  final String message;

  const ValidationIssue({
    required this.severity,
    required this.sourceFile,
    required this.jsonPath,
    required this.message,
  });

  @override
  String toString() =>
      'ValidationIssue(${severity.name}, $sourceFile, $jsonPath, $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationIssue &&
        other.severity == severity &&
        other.sourceFile == sourceFile &&
        other.jsonPath == jsonPath &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(severity, sourceFile, jsonPath, message);
}

/// Pure-function validator that checks a [ContentState] against all
/// structural and semantic rules.
///
/// Given the same [ContentState], [validateAll] always returns the same
/// list of issues.
class ContentValidator {
  /// Runs **all** error-level and warning-level checks and returns every issue found.
  List<ValidationIssue> validateAll(ContentState state) {
    final issues = <ValidationIssue>[];

    // Error-level checks
    _validateSeriesIds(state, issues);
    _validateBookIds(state, issues);
    _validateLevelIds(state, issues);
    _validateBookSeriesFK(state, issues);
    _validateLevelBookFK(state, issues);
    _validateRewardBookFK(state, issues);
    _validateContentFileBookIdConsistency(state, issues);
    _validateSeriesSortOrder(state, issues);
    _validateBookOrder(state, issues);
    _validateLevelOrder(state, issues);
    _validateQuestions(state, issues);
    _validateContentFileExistence(state, issues);
    _validateAssetImages(state, issues);
    _validateRequiredFields(state, issues);

    // Warning-level checks
    _validateEmptyExplanation(state, issues);
    _validateDuplicateQuestionText(state, issues);

    return issues;
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.5  Series IDs — unique positive integers
  // ──────────────────────────────────────────────────────────────────
  void _validateSeriesIds(ContentState state, List<ValidationIssue> issues) {
    final seen = <int>{};
    for (var i = 0; i < state.series.length; i++) {
      final s = state.series[i];
      if (s.id <= 0) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: '\$[$i].id',
          message: 'Series ID must be a positive integer, got ${s.id}',
        ));
      }
      if (!seen.add(s.id)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: '\$[$i].id',
          message: 'Duplicate series ID: ${s.id}',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.4  Book IDs — unique positive integers
  // ──────────────────────────────────────────────────────────────────
  void _validateBookIds(ContentState state, List<ValidationIssue> issues) {
    final seen = <int>{};
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      if (b.id <= 0) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].id',
          message: 'Book ID must be a positive integer, got ${b.id}',
        ));
      }
      if (!seen.add(b.id)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].id',
          message: 'Duplicate book ID: ${b.id}',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.1  Level IDs — unique positive integers across ALL books
  // ──────────────────────────────────────────────────────────────────
  void _validateLevelIds(ContentState state, List<ValidationIssue> issues) {
    // Remember where each ID was first seen. Save gating only blocks the file
    // an issue names, so reporting a collision against the file that happens
    // to be iterated second would let the other one be written to disk.
    final firstSeen = <int, (String sourceFile, int index)>{};
    final reportedFirst = <int>{};

    ValidationIssue duplicate(String sourceFile, int index, int id) =>
        ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: sourceFile,
          jsonPath: '\$.levels[$index].id',
          message: 'Duplicate level ID across all books: $id',
        );

    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        if (level.id <= 0) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels[$i].id',
            message: 'Level ID must be a positive integer, got ${level.id}',
          ));
        }
        final first = firstSeen[level.id];
        if (first == null) {
          firstSeen[level.id] = (fileName, i);
          continue;
        }
        if (reportedFirst.add(level.id)) {
          issues.add(duplicate(first.$1, first.$2, level.id));
        }
        issues.add(duplicate(fileName, i, level.id));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.3  Book → Series FK
  // ──────────────────────────────────────────────────────────────────
  void _validateBookSeriesFK(
      ContentState state, List<ValidationIssue> issues) {
    final seriesIds = state.series.map((s) => s.id).toSet();
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      if (!seriesIds.contains(b.seriesId)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].series_id',
          message:
              'Book "${b.title}" references non-existent series ID: ${b.seriesId}',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.2  Level → Book FK
  // ──────────────────────────────────────────────────────────────────
  void _validateLevelBookFK(
      ContentState state, List<ValidationIssue> issues) {
    final bookIds = state.books.map((b) => b.id).toSet();
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        if (!bookIds.contains(level.bookId)) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels[$i].book_id',
            message:
                'Level "${level.title}" references non-existent book ID: ${level.bookId}',
          ));
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.15  Reward → Book FK
  // ──────────────────────────────────────────────────────────────────
  void _validateRewardBookFK(
      ContentState state, List<ValidationIssue> issues) {
    final bookIds = state.books.map((b) => b.id).toSet();
    for (var i = 0; i < state.rewards.length; i++) {
      final r = state.rewards[i];
      if (!bookIds.contains(r.unlockBookId)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'rewards.json',
          jsonPath: '\$[$i].unlock_book_id',
          message:
              'Reward "${r.title}" references non-existent book ID: ${r.unlockBookId}',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.17  Content-file book_id consistency
  // ──────────────────────────────────────────────────────────────────
  void _validateContentFileBookIdConsistency(
      ContentState state, List<ValidationIssue> issues) {
    // Every book that names a file must be checked. A Map<file, bookId>
    // keeps only the last writer, so a second book pointing at the same
    // file (with levels tagged for that last id) used to look consistent
    // and books.json would still save — the seeder then inserts the same
    // level PK once per book.
    final refs = <String, List<(int index, int id)>>{};
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      refs.putIfAbsent(b.contentFile, () => []).add((i, b.id));
    }

    for (final entry in refs.entries) {
      if (entry.value.length < 2) continue;
      for (final (index, _) in entry.value) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$index].content_file',
          message:
              'content_file "${entry.key}" is referenced by multiple books',
        ));
      }
    }

    for (final entry in state.contentFiles.entries) {
      final contentFileName = entry.key;
      final levels = entry.value;
      final books = refs[contentFileName];
      if (books == null) {
        // This is handled by content file existence check (10.13) — skip here.
        continue;
      }
      for (final (_, expectedBookId) in books) {
        for (var i = 0; i < levels.length; i++) {
          final level = levels[i];
          if (level.bookId != expectedBookId) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: 'content/$contentFileName',
              jsonPath: '\$.levels[$i].book_id',
              message:
                  'Level book_id (${level.bookId}) is inconsistent with the '
                  'book (ID $expectedBookId) that references content file '
                  '"$contentFileName"',
            ));
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.8  Series sort_order — sequential starting from 1
  // ──────────────────────────────────────────────────────────────────
  void _validateSeriesSortOrder(
      ContentState state, List<ValidationIssue> issues) {
    if (state.series.isEmpty) return;
    final sorted = [...state.series]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].sortOrder != i + 1) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: '\$',
          message:
              'Series sort_order values are not sequential starting from 1. '
              'Expected ${i + 1} at position $i but got ${sorted[i].sortOrder}',
        ));
        break; // One error per group is sufficient
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.7  Book order within each series — sequential starting from 1
  // ──────────────────────────────────────────────────────────────────
  void _validateBookOrder(ContentState state, List<ValidationIssue> issues) {
    // Group books by series
    final booksBySeries = <int, List<dynamic>>{};
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      booksBySeries.putIfAbsent(b.seriesId, () => []).add(b);
    }

    for (final entry in booksBySeries.entries) {
      final seriesId = entry.key;
      final books = entry.value;
      books.sort((a, b) => (a.bookOrder as int).compareTo(b.bookOrder as int));
      for (var i = 0; i < books.length; i++) {
        if (books[i].bookOrder != i + 1) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: 'books.json',
            jsonPath: '\$',
            message:
                'book_order values within series $seriesId are not sequential '
                'starting from 1. Expected ${i + 1} at position $i but got '
                '${books[i].bookOrder}',
          ));
          break;
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.6  Level order within each book — sequential starting from 1
  // ──────────────────────────────────────────────────────────────────
  void _validateLevelOrder(ContentState state, List<ValidationIssue> issues) {
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = [...entry.value]
        ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
      for (var i = 0; i < levels.length; i++) {
        if (levels[i].levelOrder != i + 1) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels',
            message:
                'level_order values are not sequential starting from 1. '
                'Expected ${i + 1} at position $i but got '
                '${levels[i].levelOrder}',
          ));
          break;
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.9, 10.10, 10.11, 10.12, 10.18  Question-level checks
  // ──────────────────────────────────────────────────────────────────
  void _validateQuestions(ContentState state, List<ValidationIssue> issues) {
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        for (var qi = 0; qi < level.questions.length; qi++) {
          final q = level.questions[qi];
          final qPath = '\$.levels[$li].questions[$qi]';

          // 10.19 — type must be one of the four the app can render. Anything
          // else falls back to multiple choice there and skips every
          // type-specific rule here.
          if (!ValidationRules.validQuestionTypes.contains(q.type)) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.type',
              message:
                  'Unknown question type "${q.type}" — must be one of '
                  '${ValidationRules.validQuestionTypes.join(', ')}',
            ));
          }

          // 10.9 — correct_option must be A, B, C, or D
          if (!ValidationRules.validCorrectOptions.contains(q.correctOption)) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.correct_option',
              message:
                  'correct_option must be one of A, B, C, D — got '
                  '"${q.correctOption}"',
            ));
          }

          // 10.18 — correct_option must point at an option that has text.
          // The app maps the letter to an index and renders that option as the
          // right answer; an empty string there is an unpickable answer.
          final options = {
            'A': q.optionA,
            'B': q.optionB,
            'C': q.optionC,
            'D': q.optionD,
          };
          final answer = options[q.correctOption];
          if (answer != null && answer.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.correct_option',
              message:
                  'correct_option "${q.correctOption}" points at an empty '
                  'option_${q.correctOption.toLowerCase()}',
            ));
          }

          // 10.10 — true_false: option_c and option_d must be empty strings
          if (q.type == 'true_false') {
            if (q.optionC.isNotEmpty) {
              issues.add(ValidationIssue(
                severity: ValidationSeverity.error,
                sourceFile: fileName,
                jsonPath: '$qPath.option_c',
                message:
                    'true_false question must have empty option_c, '
                    'got "${q.optionC}"',
              ));
            }
            if (q.optionD.isNotEmpty) {
              issues.add(ValidationIssue(
                severity: ValidationSeverity.error,
                sourceFile: fileName,
                jsonPath: '$qPath.option_d',
                message:
                    'true_false question must have empty option_d, '
                    'got "${q.optionD}"',
              ));
            }
          }

          // 10.11 — matching: each option must split into exactly one
          // left/right pair. The app renders anything else as "Hata", so a
          // second separator is just as broken as a missing one.
          if (q.type == 'matching') {
            for (final optEntry in {
              'option_a': q.optionA,
              'option_b': q.optionB,
              'option_c': q.optionC,
              'option_d': q.optionD,
            }.entries) {
              final parts =
                  optEntry.value.split(ValidationRules.matchingSeparator);
              if (parts.length != 2) {
                issues.add(ValidationIssue(
                  severity: ValidationSeverity.error,
                  sourceFile: fileName,
                  jsonPath: '$qPath.${optEntry.key}',
                  message:
                      'matching question option must contain exactly one "|" '
                      'separator — got "${optEntry.value}"',
                ));
              }
            }
          }

          // 10.12 — sorting: correct_option must be "A"
          if (q.type == 'sorting' &&
              q.correctOption != ValidationRules.sortingCorrectOption) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.correct_option',
              message:
                  'sorting question must have correct_option "A", '
                  'got "${q.correctOption}"',
            ));
          }

          // 10.20 — sorting: the app shuffles all four options and compares
          // the whole list, so an empty item is an unsolvable question.
          if (q.type == 'sorting') {
            for (final optEntry in {
              'option_c': q.optionC,
              'option_d': q.optionD,
            }.entries) {
              if (optEntry.value.isEmpty) {
                issues.add(ValidationIssue(
                  severity: ValidationSeverity.error,
                  sourceFile: fileName,
                  jsonPath: '$qPath.${optEntry.key}',
                  message:
                      'sorting question must have four non-empty items — '
                      '${optEntry.key} is empty',
                ));
              }
            }
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.13  content_file — filename only, must exist in contentFiles map
  // ──────────────────────────────────────────────────────────────────
  void _validateContentFileExistence(
      ContentState state, List<ValidationIssue> issues) {
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];

      // Must be filename only (no path separators)
      if (b.contentFile.contains('/') || b.contentFile.contains('\\')) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].content_file',
          message:
              'content_file must be a filename only (no path prefix), '
              'got "${b.contentFile}"',
        ));
      }

      // Must have a corresponding entry in contentFiles
      if (!state.contentFiles.containsKey(b.contentFile)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].content_file',
          message:
              'No content file found for "${b.contentFile}"',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.14  asset_image paths must start with "assets/"
  // ──────────────────────────────────────────────────────────────────
  void _validateAssetImages(
      ContentState state, List<ValidationIssue> issues) {
    // Books
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      if (b.assetImage.isNotEmpty &&
          !b.assetImage.startsWith(ValidationRules.assetImagePrefix)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].asset_image',
          message:
              'asset_image must start with "assets/", got "${b.assetImage}"',
        ));
      }
    }

    // Levels
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        if (level.assetImage != null &&
            level.assetImage!.isNotEmpty &&
            !level.assetImage!.startsWith(ValidationRules.assetImagePrefix)) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels[$i].asset_image',
            message:
                'asset_image must start with "assets/", '
                'got "${level.assetImage}"',
          ));
        }
      }
    }

    // Rewards
    for (var i = 0; i < state.rewards.length; i++) {
      final r = state.rewards[i];
      if (r.assetImage.isNotEmpty &&
          !r.assetImage.startsWith(ValidationRules.assetImagePrefix)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'rewards.json',
          jsonPath: '\$[$i].asset_image',
          message:
              'asset_image must start with "assets/", got "${r.assetImage}"',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 10.16  Required fields — non-empty strings
  // ──────────────────────────────────────────────────────────────────
  void _validateRequiredFields(
      ContentState state, List<ValidationIssue> issues) {
    // Series: name
    for (var i = 0; i < state.series.length; i++) {
      final s = state.series[i];
      if (s.name.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: '\$[$i].name',
          message: 'Series name is required and must not be empty',
        ));
      }
    }

    // Books: title, description, content_file
    for (var i = 0; i < state.books.length; i++) {
      final b = state.books[i];
      if (b.title.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].title',
          message: 'Book title is required and must not be empty',
        ));
      }
      if (b.description.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].description',
          message: 'Book description is required and must not be empty',
        ));
      }
      if (b.contentFile.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: '\$[$i].content_file',
          message: 'Book content_file is required and must not be empty',
        ));
      }
    }

    // Levels: title, category_name
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        if (level.title.isEmpty) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels[$i].title',
            message: 'Level title is required and must not be empty',
          ));
        }
        if (level.categoryName.isEmpty) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.error,
            sourceFile: fileName,
            jsonPath: '\$.levels[$i].category_name',
            message: 'Level category_name is required and must not be empty',
          ));
        }
      }
    }

    // Questions: question_text, option_a, option_b, correct_option
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        for (var qi = 0; qi < level.questions.length; qi++) {
          final q = level.questions[qi];
          final qPath = '\$.levels[$li].questions[$qi]';
          if (q.questionText.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.question_text',
              message:
                  'Question question_text is required and must not be empty',
            ));
          }
          if (q.optionA.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.option_a',
              message: 'Question option_a is required and must not be empty',
            ));
          }
          if (q.optionB.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.option_b',
              message: 'Question option_b is required and must not be empty',
            ));
          }
          if (q.correctOption.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.error,
              sourceFile: fileName,
              jsonPath: '$qPath.correct_option',
              message:
                  'Question correct_option is required and must not be empty',
            ));
          }
        }
      }
    }

    // Rewards: title, description, asset_image
    for (var i = 0; i < state.rewards.length; i++) {
      final r = state.rewards[i];
      if (r.title.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'rewards.json',
          jsonPath: '\$[$i].title',
          message: 'Reward title is required and must not be empty',
        ));
      }
      if (r.description.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'rewards.json',
          jsonPath: '\$[$i].description',
          message: 'Reward description is required and must not be empty',
        ));
      }
      if (r.assetImage.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'rewards.json',
          jsonPath: '\$[$i].asset_image',
          message: 'Reward asset_image is required and must not be empty',
        ));
      }
    }

    // Hadiths: text, source
    for (var i = 0; i < state.hadiths.length; i++) {
      final h = state.hadiths[i];
      if (h.text.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'hadiths.json',
          jsonPath: '\$[$i].text',
          message: 'Hadith text is required and must not be empty',
        ));
      }
      if (h.source.isEmpty) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'hadiths.json',
          jsonPath: '\$[$i].source',
          message: 'Hadith source is required and must not be empty',
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 11.2  Question with empty explanation
  // ──────────────────────────────────────────────────────────────────
  void _validateEmptyExplanation(
      ContentState state, List<ValidationIssue> issues) {
    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        for (var qi = 0; qi < level.questions.length; qi++) {
          final q = level.questions[qi];
          if (q.explanation == null || q.explanation!.isEmpty) {
            issues.add(ValidationIssue(
              severity: ValidationSeverity.warning,
              sourceFile: fileName,
              jsonPath: '\$.levels[$li].questions[$qi].explanation',
              message: 'Question has an empty explanation',
            ));
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 11.4  Duplicate question_text after whitespace normalization
  // ──────────────────────────────────────────────────────────────────
  void _validateDuplicateQuestionText(
      ContentState state, List<ValidationIssue> issues) {
    // Collect all questions with their locations
    final questionLocations = <String, List<(String sourceFile, String jsonPath)>>{};

    for (final entry in state.contentFiles.entries) {
      final fileName = 'content/${entry.key}';
      final levels = entry.value;
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        for (var qi = 0; qi < level.questions.length; qi++) {
          final q = level.questions[qi];
          // Normalize: trim + collapse consecutive whitespace to single space
          final normalized =
              q.questionText.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (normalized.isEmpty) continue;

          final path = '\$.levels[$li].questions[$qi].question_text';
          questionLocations
              .putIfAbsent(normalized, () => [])
              .add((fileName, path));
        }
      }
    }

    // Report duplicates
    for (final entry in questionLocations.entries) {
      if (entry.value.length > 1) {
        for (final (sourceFile, jsonPath) in entry.value) {
          issues.add(ValidationIssue(
            severity: ValidationSeverity.warning,
            sourceFile: sourceFile,
            jsonPath: jsonPath,
            message:
                'Duplicate question text found (${entry.value.length} occurrences): '
                '"${entry.key}"',
          ));
        }
      }
    }
  }
}
