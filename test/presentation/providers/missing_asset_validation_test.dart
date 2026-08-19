import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/validation_providers.dart';

void main() {
  group('missingAssetValidationProvider', () {
    /// Creates a [ProviderContainer] with overrides for testing the
    /// missing asset validation provider.
    ProviderContainer createContainer({
      required http.Client mockClient,
      required ContentState contentState,
      required bool isConnected,
    }) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          contentStateProvider.overrideWith(
            (ref) => ContentNotifier(contentState),
          ),
          isServerConnectedProvider.overrideWithValue(isConnected),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns empty list when server is disconnected', () async {
      final mockClient = MockClient((request) async {
        fail('Should not make any HTTP requests when disconnected');
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: false,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);
      expect(result, isEmpty);
    });

    test('returns empty list when all referenced assets exist on server',
        () async {
      final mockClient = MockClient((request) async {
        final uri = request.url;
        if (uri.path == '/api/list/images/book_1') {
          return http.Response(
            jsonEncode([
              {
                'name': 'cover.webp',
                'path': 'images/book_1/cover.webp',
                'size': 1024,
                'type': 'file',
                'modified': '2024-01-01T00:00:00.000Z',
              },
            ]),
            200,
          );
        }
        if (uri.path == '/api/list/images/rewards') {
          return http.Response(
            jsonEncode([
              {
                'name': 'reward_1.webp',
                'path': 'images/rewards/reward_1.webp',
                'size': 2048,
                'type': 'file',
                'modified': '2024-01-01T00:00:00.000Z',
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [
          RewardModel(
            title: 'Reward 1',
            description: 'Desc',
            assetImage: 'assets/images/rewards/reward_1.webp',
            unlockBookId: 1,
          ),
        ],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);
      expect(result, isEmpty);
    });

    test('returns issues for missing assets', () async {
      final mockClient = MockClient((request) async {
        final uri = request.url;
        // images/book_1 directory has only level_1.webp, not cover.webp
        if (uri.path == '/api/list/images/book_1') {
          return http.Response(
            jsonEncode([
              {
                'name': 'level_1.webp',
                'path': 'images/book_1/level_1.webp',
                'size': 512,
                'type': 'file',
                'modified': '2024-01-01T00:00:00.000Z',
              },
            ]),
            200,
          );
        }
        if (uri.path == '/api/list/images/rewards') {
          return http.Response(
            jsonEncode([
              {
                'name': 'reward_1.webp',
                'path': 'images/rewards/reward_1.webp',
                'size': 2048,
                'type': 'file',
                'modified': '2024-01-01T00:00:00.000Z',
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
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
              categoryName: 'Cat',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 0,
              assetImage: 'assets/images/book_1/level_1.webp',
              questions: [],
            ),
          ],
        },
        rewards: [
          RewardModel(
            title: 'Reward 1',
            description: 'Desc',
            assetImage: 'assets/images/rewards/reward_1.webp',
            unlockBookId: 1,
          ),
        ],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);

      // Only the book cover is missing; level_1.webp and reward_1.webp exist
      expect(result, hasLength(1));
      expect(result.first.severity, ValidationSeverity.warning);
      expect(
          result.first.message, contains('assets/images/book_1/cover.webp'));
      expect(result.first.sourceFile, 'books.json');
    });

    test('returns empty list when content has no asset references', () async {
      final mockClient = MockClient((request) async {
        fail('Should not make any HTTP requests when no assets referenced');
      });

      const state = ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);
      expect(result, isEmpty);
    });

    test('reports multiple missing assets from different sources', () async {
      final mockClient = MockClient((request) async {
        // All directories return empty — everything is missing
        return http.Response(jsonEncode([]), 200);
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
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
              categoryName: 'Cat',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 0,
              assetImage: 'assets/images/book_1/level_1.webp',
              questions: [],
            ),
          ],
        },
        rewards: [
          RewardModel(
            title: 'Reward 1',
            description: 'Desc',
            assetImage: 'assets/images/rewards/reward_1.webp',
            unlockBookId: 1,
          ),
        ],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);

      expect(result, hasLength(3));
      expect(
        result.every((issue) => issue.severity == ValidationSeverity.warning),
        isTrue,
      );

      final messages = result.map((i) => i.message).toList();
      expect(
          messages, contains(contains('assets/images/book_1/cover.webp')));
      expect(
          messages, contains(contains('assets/images/book_1/level_1.webp')));
      expect(messages,
          contains(contains('assets/images/rewards/reward_1.webp')));
    });

    test('reports nothing when the directory listing itself fails', () async {
      // A 500 means "could not check", not "file is gone". Reporting every
      // reference in the directory as missing turns one transient server
      // error into a pile of warnings that drags the health score down.
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal server error'}),
          500,
        );
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);

      expect(
        result,
        isEmpty,
        reason: 'a failed listing says nothing about whether the asset exists',
      );
    });

    test('reports assets as missing when the directory does not exist',
        () async {
      // A 404 from /api/list is the server telling us the directory is not
      // there, so everything referenced inside it really is missing.
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Directory not found: images/book_1'}),
          404,
        );
      });

      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/book_1/cover.webp',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      final container = createContainer(
        mockClient: mockClient,
        contentState: state,
        isConnected: true,
      );

      final result =
          await container.read(missingAssetValidationProvider.future);

      expect(result, hasLength(1));
      expect(result.first.severity, ValidationSeverity.warning);
      expect(
          result.first.message, contains('assets/images/book_1/cover.webp'));
    });
  });
}
