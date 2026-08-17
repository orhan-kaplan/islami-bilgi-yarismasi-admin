import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';

import '../../helpers/content_generators.dart';

void main() {
  // Feature: admin-tool-enhancements, Property 14: JSON preview produces valid indented JSON that round-trips
  group('Property 14: JSON preview produces valid indented JSON that round-trips', () {
    /// **Validates: Requirements 7.2, 7.3, 7.4, 7.5, 7.6**

    const encoder = JsonEncoder.withIndent('  ');

    Glados(any.seriesModel, ExploreConfig(numRuns: 100)).test(
      'SeriesModel: toJson → indented JSON → jsonDecode → fromJson equals original',
      (series) {
        // Generate JSON preview using 2-space indentation
        final preview = encoder.convert(series.toJson());

        // 1. Must be valid JSON parseable by jsonDecode
        final decoded = jsonDecode(preview);
        expect(decoded, isA<Map<String, dynamic>>(),
            reason: 'JSON preview of SeriesModel must decode to a Map');

        // 2. Must use 2-space indentation
        final lines = preview.split('\n');
        final indentedLines = lines.where((l) => l.startsWith('  '));
        expect(indentedLines.isNotEmpty, isTrue,
            reason:
                'JSON preview must contain lines with 2-space indentation');

        // 3. Round-trip: fromJson(jsonDecode(preview)) == original
        final roundTripped =
            SeriesModel.fromJson(decoded as Map<String, dynamic>);
        expect(roundTripped, equals(series),
            reason:
                'SeriesModel.fromJson(jsonDecode(preview)) must equal the original model');
      },
    );

    Glados(any.bookModel, ExploreConfig(numRuns: 100)).test(
      'BookModel: toJson → indented JSON → jsonDecode → fromJson equals original',
      (book) {
        // Generate JSON preview using 2-space indentation
        final preview = encoder.convert(book.toJson());

        // 1. Must be valid JSON parseable by jsonDecode
        final decoded = jsonDecode(preview);
        expect(decoded, isA<Map<String, dynamic>>(),
            reason: 'JSON preview of BookModel must decode to a Map');

        // 2. Must use 2-space indentation
        final lines = preview.split('\n');
        final indentedLines = lines.where((l) => l.startsWith('  '));
        expect(indentedLines.isNotEmpty, isTrue,
            reason:
                'JSON preview must contain lines with 2-space indentation');

        // 3. Round-trip: fromJson(jsonDecode(preview)) == original
        final roundTripped =
            BookModel.fromJson(decoded as Map<String, dynamic>);
        expect(roundTripped, equals(book),
            reason:
                'BookModel.fromJson(jsonDecode(preview)) must equal the original model');
      },
    );

    Glados(any.levelModel, ExploreConfig(numRuns: 100)).test(
      'LevelModel: toJson → indented JSON → jsonDecode → fromJson equals original',
      (level) {
        // Generate JSON preview using 2-space indentation
        final preview = encoder.convert(level.toJson());

        // 1. Must be valid JSON parseable by jsonDecode
        final decoded = jsonDecode(preview);
        expect(decoded, isA<Map<String, dynamic>>(),
            reason: 'JSON preview of LevelModel must decode to a Map');

        // 2. Must use 2-space indentation (nested questions array should have deeper indentation)
        final lines = preview.split('\n');
        final indentedLines = lines.where((l) => l.startsWith('  '));
        expect(indentedLines.isNotEmpty, isTrue,
            reason:
                'JSON preview must contain lines with 2-space indentation');

        // Verify deeper nesting for questions array (4-space indent)
        if (level.questions.isNotEmpty) {
          final deepIndentedLines = lines.where((l) => l.startsWith('    '));
          expect(deepIndentedLines.isNotEmpty, isTrue,
              reason:
                  'JSON preview of LevelModel with questions must have nested 4-space indentation');
        }

        // 3. Round-trip: fromJson(jsonDecode(preview)) == original
        final roundTripped =
            LevelModel.fromJson(decoded as Map<String, dynamic>);
        expect(roundTripped, equals(level),
            reason:
                'LevelModel.fromJson(jsonDecode(preview)) must equal the original model');
      },
    );

    Glados(any.questionModel, ExploreConfig(numRuns: 100)).test(
      'QuestionModel: toJson → indented JSON → jsonDecode → fromJson equals original',
      (question) {
        // Generate JSON preview using 2-space indentation
        final preview = encoder.convert(question.toJson());

        // 1. Must be valid JSON parseable by jsonDecode
        final decoded = jsonDecode(preview);
        expect(decoded, isA<Map<String, dynamic>>(),
            reason: 'JSON preview of QuestionModel must decode to a Map');

        // 2. Must use 2-space indentation
        final lines = preview.split('\n');
        final indentedLines = lines.where((l) => l.startsWith('  '));
        expect(indentedLines.isNotEmpty, isTrue,
            reason:
                'JSON preview must contain lines with 2-space indentation');

        // 3. Round-trip: fromJson(jsonDecode(preview)) == original
        final roundTripped =
            QuestionModel.fromJson(decoded as Map<String, dynamic>);
        expect(roundTripped, equals(question),
            reason:
                'QuestionModel.fromJson(jsonDecode(preview)) must equal the original model');
      },
    );
  });
}
