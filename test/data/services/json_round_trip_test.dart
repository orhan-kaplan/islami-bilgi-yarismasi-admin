import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_parser.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_serializer.dart';

import '../../helpers/content_generators.dart';

void main() {
  final parser = JsonParser();
  final serializer = JsonSerializer();

  group('Property 1: JSON Round-Trip Integrity', () {
    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'serialize then parse produces semantically equivalent ContentState',
      (state) {
        // Serialize each part of the state
        final seriesJson = serializer.serializeSeries(state.series);
        final booksJson = serializer.serializeBooks(state.books);
        final rewardsJson = serializer.serializeRewards(state.rewards);
        final hadithsJson = serializer.serializeHadiths(state.hadiths);

        // Serialize content files
        final contentFileJsons = <String, String>{};
        for (final entry in state.contentFiles.entries) {
          contentFileJsons[entry.key] =
              serializer.serializeContentFile(entry.value);
        }

        // Parse back
        final parsedSeries = parser.parseSeries(seriesJson);
        final parsedBooks = parser.parseBooks(booksJson);
        final parsedRewards = parser.parseRewards(rewardsJson);
        final parsedHadiths = parser.parseHadiths(hadithsJson);

        final parsedContentFiles = <String, List<LevelModel>>{};
        for (final entry in contentFileJsons.entries) {
          parsedContentFiles[entry.key] =
              parser.parseContentFile(entry.value);
        }

        // Reconstruct state and verify semantic equivalence
        final reconstructed = ContentState(
          series: parsedSeries,
          books: parsedBooks,
          contentFiles: parsedContentFiles,
          rewards: parsedRewards,
          hadiths: parsedHadiths,
        );

        expect(reconstructed.series, equals(state.series));
        expect(reconstructed.books, equals(state.books));
        expect(reconstructed.rewards, equals(state.rewards));
        expect(reconstructed.hadiths, equals(state.hadiths));

        // Verify content files map equality
        expect(
          reconstructed.contentFiles.keys.toSet(),
          equals(state.contentFiles.keys.toSet()),
        );
        for (final key in state.contentFiles.keys) {
          expect(
            reconstructed.contentFiles[key],
            equals(state.contentFiles[key]),
            reason:
                'Content file "$key" should be equivalent after round-trip',
          );
        }
      },
    );

    Glados(
      any.listWithLengthInRange(0, 6, any.seriesModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'series round-trip preserves Turkish characters and emoji',
      (seriesList) {
        final json = serializer.serializeSeries(seriesList);
        final parsed = parser.parseSeries(json);

        expect(parsed.length, equals(seriesList.length));
        for (var i = 0; i < seriesList.length; i++) {
          expect(parsed[i], equals(seriesList[i]));
        }
      },
    );

    Glados(
      any.listWithLengthInRange(0, 6, any.bookModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'books round-trip preserves all fields',
      (booksList) {
        final json = serializer.serializeBooks(booksList);
        final parsed = parser.parseBooks(json);

        expect(parsed.length, equals(booksList.length));
        for (var i = 0; i < booksList.length; i++) {
          expect(parsed[i], equals(booksList[i]));
        }
      },
    );

    Glados(
      any.listWithLengthInRange(0, 4, any.levelModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'content file round-trip preserves nested questions with all types',
      (levels) {
        final json = serializer.serializeContentFile(levels);
        final parsed = parser.parseContentFile(json);

        expect(parsed.length, equals(levels.length));
        for (var i = 0; i < levels.length; i++) {
          expect(parsed[i], equals(levels[i]));
          expect(
            parsed[i].questions.length,
            equals(levels[i].questions.length),
          );
          for (var j = 0; j < levels[i].questions.length; j++) {
            expect(parsed[i].questions[j], equals(levels[i].questions[j]));
          }
        }
      },
    );

    Glados(
      any.listWithLengthInRange(0, 6, any.rewardModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'rewards round-trip preserves all fields',
      (rewardsList) {
        final json = serializer.serializeRewards(rewardsList);
        final parsed = parser.parseRewards(json);

        expect(parsed.length, equals(rewardsList.length));
        for (var i = 0; i < rewardsList.length; i++) {
          expect(parsed[i], equals(rewardsList[i]));
        }
      },
    );

    Glados(
      any.listWithLengthInRange(0, 8, any.hadithModel),
      ExploreConfig(numRuns: 100),
    ).test(
      'hadiths round-trip preserves Turkish text and source',
      (hadithsList) {
        final json = serializer.serializeHadiths(hadithsList);
        final parsed = parser.parseHadiths(json);

        expect(parsed.length, equals(hadithsList.length));
        for (var i = 0; i < hadithsList.length; i++) {
          expect(parsed[i], equals(hadithsList[i]));
        }
      },
    );
  });
}
