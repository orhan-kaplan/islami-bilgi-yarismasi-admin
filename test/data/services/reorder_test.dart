import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

import '../../helpers/content_generators.dart';

void main() {
  // Feature: admin-tool-enhancements, Property 1: Reorder produces sequential order values
  // **Validates: Requirements 1.4, 1.5, 1.6**
  group('Property 1: Reorder produces sequential order values', () {
    Glados(
      any.listWithLengthInRange(2, 6, any.seriesModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'reorderSeries produces sequential 1..N sort_order values and preserves item set',
      (seriesList) {
        // Ensure unique IDs by assigning sequential IDs
        final uniqueSeries = <SeriesModel>[];
        for (var i = 0; i < seriesList.length; i++) {
          uniqueSeries.add(seriesList[i].copyWith(id: i + 1));
        }

        // Create a ContentNotifier with the series
        final notifier = ContentNotifier(ContentState(
          series: uniqueSeries,
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a shuffled permutation of IDs
        final ids = uniqueSeries.map((s) => s.id).toList();
        final shuffledIds = List<int>.from(ids)..shuffle();

        // Call reorderSeries
        notifier.reorderSeries(shuffledIds);

        final result = notifier.state.series;

        // Verify sequential order values 1..N
        final orderValues = result.map((s) => s.sortOrder).toList();
        expect(orderValues, equals(List.generate(result.length, (i) => i + 1)));

        // Verify the resulting set of IDs is the same as the input
        final resultIds = result.map((s) => s.id).toSet();
        final inputIds = uniqueSeries.map((s) => s.id).toSet();
        expect(resultIds, equals(inputIds));

        // Verify the order of IDs matches the shuffled order
        final resultIdOrder = result.map((s) => s.id).toList();
        expect(resultIdOrder, equals(shuffledIds));
      },
    );

    Glados(
      any.listWithLengthInRange(2, 6, any.bookModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'reorderBooks produces sequential 1..N book_order values and preserves item set',
      (booksList) {
        // Ensure unique IDs and same seriesId
        const seriesId = 1;
        final uniqueBooks = <BookModel>[];
        for (var i = 0; i < booksList.length; i++) {
          uniqueBooks.add(booksList[i].copyWith(id: i + 1, seriesId: seriesId));
        }

        // Create a ContentNotifier with the books
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: uniqueBooks,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a shuffled permutation of IDs
        final ids = uniqueBooks.map((b) => b.id).toList();
        final shuffledIds = List<int>.from(ids)..shuffle();

        // Call reorderBooks
        notifier.reorderBooks(seriesId, shuffledIds);

        final result = notifier.state.books;

        // Verify sequential order values 1..N
        final orderValues = result.map((b) => b.bookOrder).toList()..sort();
        expect(orderValues, equals(List.generate(result.length, (i) => i + 1)));

        // Verify the resulting set of IDs is the same as the input
        final resultIds = result.map((b) => b.id).toSet();
        final inputIds = uniqueBooks.map((b) => b.id).toSet();
        expect(resultIds, equals(inputIds));

        // Verify each book has the correct order based on shuffled position
        for (var i = 0; i < shuffledIds.length; i++) {
          final book = result.firstWhere((b) => b.id == shuffledIds[i]);
          expect(book.bookOrder, equals(i + 1));
        }
      },
    );

    Glados(
      any.listWithLengthInRange(2, 6, any.levelModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'reorderLevels produces sequential 1..N level_order values and preserves item set',
      (levelsList) {
        // Ensure unique IDs and same bookId
        const contentFile = 'book_1.json';
        final uniqueLevels = <LevelModel>[];
        for (var i = 0; i < levelsList.length; i++) {
          uniqueLevels.add(levelsList[i].copyWith(id: i + 1));
        }

        // Create a ContentNotifier with the levels
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {contentFile: uniqueLevels},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a shuffled permutation of IDs
        final ids = uniqueLevels.map((l) => l.id).toList();
        final shuffledIds = List<int>.from(ids)..shuffle();

        // Call reorderLevels
        notifier.reorderLevels(contentFile, shuffledIds);

        final result = notifier.state.contentFiles[contentFile]!;

        // Verify sequential order values 1..N
        final orderValues = result.map((l) => l.levelOrder).toList()..sort();
        expect(orderValues, equals(List.generate(result.length, (i) => i + 1)));

        // Verify the resulting set of IDs is the same as the input
        final resultIds = result.map((l) => l.id).toSet();
        final inputIds = uniqueLevels.map((l) => l.id).toSet();
        expect(resultIds, equals(inputIds));

        // Verify each level has the correct order based on shuffled position
        for (var i = 0; i < shuffledIds.length; i++) {
          final level = result.firstWhere((l) => l.id == shuffledIds[i]);
          expect(level.levelOrder, equals(i + 1));
        }
      },
    );
  });
}
