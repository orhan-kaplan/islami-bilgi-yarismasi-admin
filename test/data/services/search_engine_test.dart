import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/services/search_engine.dart';

import '../../helpers/content_generators.dart';

void main() {
  // Feature: admin-tool-enhancements, Property 7: Turkish normalization is idempotent and maps character pairs
  group('Property 7: Turkish normalization is idempotent and maps character pairs', () {
    /// **Validates: Requirements 4.4, 4.8**

    Glados(any.turkishString, ExploreConfig(numRuns: 100)).test(
      'normalize(normalize(x)) == normalize(x) for any Turkish string',
      (input) {
        final once = SearchEngine.normalize(input);
        final twice = SearchEngine.normalize(once);

        expect(twice, equals(once),
            reason:
                'Normalization must be idempotent: applying it twice should produce the same result as applying it once. Input: "$input"');
      },
    );

    group('Turkish character mappings', () {
      test('ı stays as ı (distinct from i)', () {
        expect(SearchEngine.normalize('ı'), equals('ı'));
      });

      test('İ maps to i', () {
        expect(SearchEngine.normalize('İ'), equals('i'));
      });

      test('I maps to ı (Turkish uppercase I)', () {
        expect(SearchEngine.normalize('I'), equals('ı'));
      });

      test('ö stays as ö', () {
        expect(SearchEngine.normalize('ö'), equals('ö'));
      });

      test('Ö maps to ö', () {
        expect(SearchEngine.normalize('Ö'), equals('ö'));
      });

      test('ü stays as ü', () {
        expect(SearchEngine.normalize('ü'), equals('ü'));
      });

      test('Ü maps to ü', () {
        expect(SearchEngine.normalize('Ü'), equals('ü'));
      });

      test('ş stays as ş', () {
        expect(SearchEngine.normalize('ş'), equals('ş'));
      });

      test('Ş maps to ş', () {
        expect(SearchEngine.normalize('Ş'), equals('ş'));
      });

      test('ç stays as ç', () {
        expect(SearchEngine.normalize('ç'), equals('ç'));
      });

      test('Ç maps to ç', () {
        expect(SearchEngine.normalize('Ç'), equals('ç'));
      });

      test('ğ stays as ğ', () {
        expect(SearchEngine.normalize('ğ'), equals('ğ'));
      });

      test('Ğ maps to ğ', () {
        expect(SearchEngine.normalize('Ğ'), equals('ğ'));
      });
    });

    group('Lowercasing', () {
      test('uppercase Latin characters are lowercased', () {
        expect(SearchEngine.normalize('ABC'), equals('abc'));
      });

      test('mixed Turkish and Latin characters normalize correctly', () {
        expect(SearchEngine.normalize('İstanbul'), equals('istanbul'));
      });

      test('already lowercase string is unchanged', () {
        expect(SearchEngine.normalize('hello'), equals('hello'));
      });

      test('ı is preserved in lowercase', () {
        expect(SearchEngine.normalize('ılık'), equals('ılık'));
      });
    });

    group('Idempotency edge cases', () {
      test('empty string normalizes to empty string', () {
        final result = SearchEngine.normalize('');
        expect(result, equals(''));
        expect(SearchEngine.normalize(result), equals(result));
      });

      test('string with all Turkish characters is idempotent', () {
        const input = 'ıİöÖüÜşŞçÇğĞ';
        final once = SearchEngine.normalize(input);
        final twice = SearchEngine.normalize(once);
        expect(once, equals('ıiööüüşşççğğ'));
        expect(twice, equals(once));
      });

      test('string with spaces and punctuation is idempotent', () {
        const input = 'Merhaba Dünya! Güneş çok güzel.';
        final once = SearchEngine.normalize(input);
        final twice = SearchEngine.normalize(once);
        expect(twice, equals(once));
      });
    });
  });

  // Feature: admin-tool-enhancements, Property 8: Search results include all ancestors of matching items
  group('Property 8: Search results include all ancestors of matching items', () {
    /// **Validates: Requirements 4.5**

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'if a book matches, its parent series appears in visibleSeriesIds',
      (state) {
        // Skip if no books
        if (state.books.isEmpty) return;

        // Use a substring from the first book's title as query
        final bookTitle = state.books.first.title.trim();
        if (bookTitle.isEmpty) return;
        final query = bookTitle.length >= 2
            ? bookTitle.substring(0, 2)
            : bookTitle;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        // For every book whose title actually matches the query,
        // its seriesId must be in visibleSeriesIds
        for (final book in state.books) {
          if (SearchEngine.normalize(book.title).contains(normalizedQuery)) {
            expect(result.visibleSeriesIds, contains(book.seriesId),
                reason:
                    'Book "${book.title}" (id=${book.id}) matches query "$query" but its parent series (seriesId=${book.seriesId}) is not in visibleSeriesIds');
          }
        }
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'if a level matches, its parent book and grandparent series appear in visible sets',
      (state) {
        // Skip if no content files with levels
        if (state.contentFiles.isEmpty) return;

        // Find a level with a non-empty title to use as query
        String? query;
        for (final levels in state.contentFiles.values) {
          for (final level in levels) {
            final title = level.title.trim();
            if (title.length >= 2) {
              query = title.substring(0, 2);
              break;
            } else if (title.isNotEmpty) {
              query = title;
              break;
            }
          }
          if (query != null) break;
        }
        if (query == null) return;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        // For every level whose title actually matches the query,
        // check its ancestors via content file lookup
        for (final entry in state.contentFiles.entries) {
          final contentFile = entry.key;
          final levels = entry.value;

          // Find the parent book for this content file
          final parentBook = state.books
              .where((b) => b.contentFile == contentFile)
              .firstOrNull;

          for (final level in levels) {
            if (SearchEngine.normalize(level.title).contains(normalizedQuery)) {
              if (parentBook != null) {
                expect(result.visibleBookIds, contains(parentBook.id),
                    reason:
                        'Level "${level.title}" (id=${level.id}) matches but its parent book (id=${parentBook.id}) is not in visibleBookIds');
                expect(result.visibleSeriesIds, contains(parentBook.seriesId),
                    reason:
                        'Level "${level.title}" (id=${level.id}) matches but its grandparent series (seriesId=${parentBook.seriesId}) is not in visibleSeriesIds');
              }
            }
          }
        }
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'if a question matches, its parent level, grandparent book, and great-grandparent series appear in visible sets',
      (state) {
        // Skip if no content files with levels that have questions
        if (state.contentFiles.isEmpty) return;

        // Find a question with non-empty text to use as query
        String? query;
        for (final levels in state.contentFiles.values) {
          for (final level in levels) {
            for (final question in level.questions) {
              final text = question.questionText.trim();
              if (text.length >= 2) {
                query = text.substring(0, 2);
                break;
              } else if (text.isNotEmpty) {
                query = text;
                break;
              }
            }
            if (query != null) break;
          }
          if (query != null) break;
        }
        if (query == null) return;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        // For every question whose text actually matches the query,
        // check its ancestors
        for (final entry in state.contentFiles.entries) {
          final contentFile = entry.key;
          final levels = entry.value;

          // Find the parent book for this content file
          final parentBook = state.books
              .where((b) => b.contentFile == contentFile)
              .firstOrNull;

          for (final level in levels) {
            for (int qi = 0; qi < level.questions.length; qi++) {
              final question = level.questions[qi];
              if (SearchEngine.normalize(question.questionText)
                  .contains(normalizedQuery)) {
                // Parent level must be visible
                expect(result.visibleLevelIds, contains(level.id),
                    reason:
                        'Question at index $qi in level ${level.id} matches but its parent level is not in visibleLevelIds');

                if (parentBook != null) {
                  // Grandparent book must be visible
                  expect(result.visibleBookIds, contains(parentBook.id),
                      reason:
                          'Question at index $qi in level ${level.id} matches but its grandparent book (id=${parentBook.id}) is not in visibleBookIds');
                  // Great-grandparent series must be visible
                  expect(
                      result.visibleSeriesIds, contains(parentBook.seriesId),
                      reason:
                          'Question at index $qi in level ${level.id} matches but its great-grandparent series (seriesId=${parentBook.seriesId}) is not in visibleSeriesIds');
                }
              }
            }
          }
        }
      },
    );
  });

  // Feature: admin-tool-enhancements, Property 9: Search filter returns only items containing the query
  group('Property 9: Search filter returns only items containing the query', () {
    /// **Validates: Requirements 4.2, 4.3**

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'every series in matchingSeriesIds has a name containing the normalized query',
      (state) {
        // Derive a query from an existing series name to ensure non-empty query
        if (state.series.isEmpty) return;
        final seriesName = state.series.first.name.trim();
        if (seriesName.isEmpty) return;
        final query = seriesName.length >= 2
            ? seriesName.substring(0, 2)
            : seriesName;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        for (final seriesId in result.matchingSeriesIds) {
          final series = state.series.firstWhere((s) => s.id == seriesId);
          final normalizedName = SearchEngine.normalize(series.name);
          expect(normalizedName.contains(normalizedQuery), isTrue,
              reason:
                  'Series "${series.name}" (id=$seriesId) is in matchingSeriesIds but its normalized name "$normalizedName" does not contain normalized query "$normalizedQuery"');
        }
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'every book in matchingBookIds has a title containing the normalized query',
      (state) {
        // Derive a query from an existing book title
        if (state.books.isEmpty) return;
        final bookTitle = state.books.first.title.trim();
        if (bookTitle.isEmpty) return;
        final query = bookTitle.length >= 2
            ? bookTitle.substring(0, 2)
            : bookTitle;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        for (final bookId in result.matchingBookIds) {
          final book = state.books.firstWhere((b) => b.id == bookId);
          final normalizedTitle = SearchEngine.normalize(book.title);
          expect(normalizedTitle.contains(normalizedQuery), isTrue,
              reason:
                  'Book "${book.title}" (id=$bookId) is in matchingBookIds but its normalized title "$normalizedTitle" does not contain normalized query "$normalizedQuery"');
        }
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'every level in matchingLevelIds has a title containing the normalized query',
      (state) {
        // Derive a query from an existing level title
        if (state.contentFiles.isEmpty) return;
        String? query;
        for (final levels in state.contentFiles.values) {
          for (final level in levels) {
            final title = level.title.trim();
            if (title.length >= 2) {
              query = title.substring(0, 2);
              break;
            } else if (title.isNotEmpty) {
              query = title;
              break;
            }
          }
          if (query != null) break;
        }
        if (query == null) return;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        for (final levelId in result.matchingLevelIds) {
          // Find the level across all content files
          bool found = false;
          for (final levels in state.contentFiles.values) {
            for (final level in levels) {
              if (level.id == levelId) {
                final normalizedTitle = SearchEngine.normalize(level.title);
                expect(normalizedTitle.contains(normalizedQuery), isTrue,
                    reason:
                        'Level "${level.title}" (id=$levelId) is in matchingLevelIds but its normalized title "$normalizedTitle" does not contain normalized query "$normalizedQuery"');
                found = true;
                break;
              }
            }
            if (found) break;
          }
        }
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'every question index in matchingQuestionIndices corresponds to a question whose text contains the normalized query',
      (state) {
        // Derive a query from an existing question text
        if (state.contentFiles.isEmpty) return;
        String? query;
        for (final levels in state.contentFiles.values) {
          for (final level in levels) {
            for (final question in level.questions) {
              final text = question.questionText.trim();
              if (text.length >= 2) {
                query = text.substring(0, 2);
                break;
              } else if (text.isNotEmpty) {
                query = text;
                break;
              }
            }
            if (query != null) break;
          }
          if (query != null) break;
        }
        if (query == null) return;

        final normalizedQuery = SearchEngine.normalize(query);
        final result = SearchEngine.filter(state, query);

        for (final encodedIndex in result.matchingQuestionIndices) {
          final levelId = encodedIndex ~/ 1000;
          final qi = encodedIndex % 1000;

          // Find any level with this ID that has enough questions and whose
          // question text contains the query. Due to possible duplicate IDs
          // across content files, we check all matching levels.
          bool verified = false;
          for (final levels in state.contentFiles.values) {
            for (final level in levels) {
              if (level.id == levelId && qi < level.questions.length) {
                final question = level.questions[qi];
                final normalizedText =
                    SearchEngine.normalize(question.questionText);
                if (normalizedText.contains(normalizedQuery)) {
                  verified = true;
                  break;
                }
              }
            }
            if (verified) break;
          }
          expect(verified, isTrue,
              reason:
                  'Encoded index $encodedIndex (levelId=$levelId, qi=$qi) is in matchingQuestionIndices but no level with id=$levelId has a question at index $qi whose normalized text contains "$normalizedQuery"');
        }
      },
    );
  });
}
