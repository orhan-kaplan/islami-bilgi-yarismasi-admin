// Feature: asset-management, Property 4: Save Gating by Validation Severity
// **Validates: Requirements 3.7**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/save_gating.dart';

/// Pool of realistic source file names used by the validator.
const _sourceFiles = [
  'series.json',
  'books.json',
  'rewards.json',
  'hadiths.json',
  'content/book_1.json',
  'content/book_2.json',
  'content/book_3.json',
];

/// Extension on [Any] to provide generators for save gating tests.
extension SaveGatingGenerators on Any {
  /// Generates a random source file name from the realistic pool.
  Generator<String> get sourceFile => simple(
        generate: (random, size) {
          return _sourceFiles[random.nextInt(_sourceFiles.length)];
        },
        shrink: (input) => [],
      );

  /// Generates a random ValidationSeverity.
  Generator<ValidationSeverity> get validationSeverity => simple(
        generate: (random, size) {
          return random.nextBool()
              ? ValidationSeverity.error
              : ValidationSeverity.warning;
        },
        shrink: (input) => [],
      );

  /// Generates a random ValidationIssue.
  Generator<ValidationIssue> get validationIssue => simple(
        generate: (random, size) {
          final severity = random.nextBool()
              ? ValidationSeverity.error
              : ValidationSeverity.warning;
          final file = _sourceFiles[random.nextInt(_sourceFiles.length)];
          return ValidationIssue(
            severity: severity,
            sourceFile: file,
            jsonPath: '\$[0].id',
            message: 'Test issue',
          );
        },
        shrink: (input) => [],
      );

  /// Generates a list of ValidationIssues with random length (0..20).
  Generator<List<ValidationIssue>> get validationIssueList => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(0, 20) + 1);
          final issues = <ValidationIssue>[];
          for (var i = 0; i < length; i++) {
            final severity = random.nextBool()
                ? ValidationSeverity.error
                : ValidationSeverity.warning;
            final file = _sourceFiles[random.nextInt(_sourceFiles.length)];
            issues.add(ValidationIssue(
              severity: severity,
              sourceFile: file,
              jsonPath: '\$[$i].id',
              message: 'Test issue $i',
            ));
          }
          return issues;
        },
        shrink: (input) => [],
      );
}

void main() {
  group('Property 4: Save Gating by Validation Severity', () {
    Glados2(any.sourceFile, any.validationIssueList,
            ExploreConfig(numRuns: 100))
        .test(
      'save allowed iff zero ERROR-level issues for target file',
      (targetSourceFile, issues) {
        // Convert sourceFile to apiPath format (prepend 'data/')
        final apiPath = 'data/$targetSourceFile';

        // Compute expected result: save allowed iff no errors for target file
        final hasErrorsForTarget = issues.any(
          (issue) =>
              issue.severity == ValidationSeverity.error &&
              issue.sourceFile == targetSourceFile,
        );
        final expectedAllowed = !hasErrorsForTarget;

        // Call the function under test
        final result = isSaveAllowedForFile(apiPath, issues);

        expect(result, equals(expectedAllowed),
            reason:
                'isSaveAllowedForFile("$apiPath", issues) should be $expectedAllowed. '
                'Target file: "$targetSourceFile", '
                'errors for target: $hasErrorsForTarget, '
                'total issues: ${issues.length}');
      },
    );

    Glados(any.validationIssueList, ExploreConfig(numRuns: 100)).test(
      'WARNING-level issues never block save',
      (issues) {
        // Pick a file that only has warnings (no errors)
        // Create a target file with only warnings
        const targetFile = 'series.json';
        const apiPath = 'data/$targetFile';

        // Filter to only keep warnings for the target file
        final warningOnlyIssues = issues
            .where((i) => i.sourceFile != targetFile)
            .toList()
          ..addAll(issues
              .where((i) =>
                  i.sourceFile == targetFile &&
                  i.severity == ValidationSeverity.warning)
              .toList());

        // With only warnings for target file, save should always be allowed
        final result = isSaveAllowedForFile(apiPath, warningOnlyIssues);
        expect(result, isTrue,
            reason:
                'Save should be allowed when only WARNING-level issues exist for target file');
      },
    );

    test('save blocked when ERROR exists for target file', () {
      const apiPath = 'data/series.json';
      final issues = [
        const ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'series.json',
          jsonPath: r'$[0].id',
          message: 'Duplicate series ID',
        ),
      ];

      expect(isSaveAllowedForFile(apiPath, issues), isFalse);
    });

    test('save allowed when ERROR exists for different file', () {
      const apiPath = 'data/series.json';
      final issues = [
        const ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: r'$[0].id',
          message: 'Duplicate book ID',
        ),
      ];

      expect(isSaveAllowedForFile(apiPath, issues), isTrue);
    });

    test('save allowed with empty issues list', () {
      const apiPath = 'data/series.json';
      expect(isSaveAllowedForFile(apiPath, []), isTrue);
    });

    test('save allowed when only warnings for target file', () {
      const apiPath = 'data/content/book_1.json';
      final issues = [
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          sourceFile: 'content/book_1.json',
          jsonPath: r'$.levels[0].questions[0].explanation',
          message: 'Question has an empty explanation',
        ),
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          sourceFile: 'content/book_1.json',
          jsonPath: r'$.levels[0].questions[1].explanation',
          message: 'Question has an empty explanation',
        ),
      ];

      expect(isSaveAllowedForFile(apiPath, issues), isTrue);
    });

    test('save blocked when mix of errors and warnings for target file', () {
      const apiPath = 'data/books.json';
      final issues = [
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          sourceFile: 'books.json',
          jsonPath: r'$[0].description',
          message: 'Description is short',
        ),
        const ValidationIssue(
          severity: ValidationSeverity.error,
          sourceFile: 'books.json',
          jsonPath: r'$[0].id',
          message: 'Duplicate book ID',
        ),
      ];

      expect(isSaveAllowedForFile(apiPath, issues), isFalse);
    });
  });
}
