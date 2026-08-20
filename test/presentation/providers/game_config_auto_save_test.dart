import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';

class _AlreadyLoadedGameConfigLoad extends GameConfigLoadNotifier {
  _AlreadyLoadedGameConfigLoad(super.ref) {
    state = GameConfigLoadStatus.loaded;
  }

  @override
  Future<void> performLoad({bool force = false}) async {}
}

void main() {
  group('GameConfigAutoSaveController', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createLoadedContainer({
      required http.Client mockClient,
    }) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          isServerConnectedProvider.overrideWithValue(true),
          gameConfigLoadProvider.overrideWith(
            (ref) => _AlreadyLoadedGameConfigLoad(ref),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('flush saves valid game_config.json', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });

      final container = createLoadedContainer(mockClient: mockClient);
      container.read(gameConfigAutoSaveProvider);

      container.read(gameConfigProvider.notifier).importContent(
            GameConfigState.fromJson({
              'quiz': {'lives': 4},
            }),
          );

      await container.read(gameConfigAutoSaveProvider.notifier).flushPendingSave();

      final puts = capturedRequests.where(
        (r) =>
            r.method == 'PUT' &&
            r.url.path == '/api/files/data/game_config.json',
      );
      expect(puts, isNotEmpty);
      final body = jsonDecode(puts.last.body) as Map<String, dynamic>;
      expect((body['quiz'] as Map)['lives'], 4);
      expect(
        container.read(gameConfigAutoSaveProvider),
        GameConfigSaveStatus.saved,
      );
    });

    test('a failed PUT is retried by the next flush', () async {
      var failNext = true;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/game_config.json') {
          if (failNext) {
            failNext = false;
            return http.Response('{"error":"disk full"}', 500);
          }
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);
      container.read(gameConfigAutoSaveProvider);

      container.read(gameConfigProvider.notifier).importContent(
            GameConfigState.fromJson({
              'quiz': {'lives': 4},
            }),
          );

      await container.read(gameConfigAutoSaveProvider.notifier).flushPendingSave();
      expect(
        container.read(gameConfigAutoSaveProvider),
        GameConfigSaveStatus.error,
      );

      // Başarısız yazım değişikliği düşürmemeli; ikinci flush yeniden denemeli.
      await container.read(gameConfigAutoSaveProvider.notifier).flushPendingSave();

      final puts = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/game_config.json')
          .toList();
      expect(puts.length, 2);
      expect(
        container.read(gameConfigAutoSaveProvider),
        GameConfigSaveStatus.saved,
      );
    });

    test('invalid config blocks PUT and marks error', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });

      final container = createLoadedContainer(mockClient: mockClient);
      container.read(gameConfigAutoSaveProvider);

      container.read(gameConfigProvider.notifier).importContent(
            GameConfigState.defaults.copyWith(
              quiz: GameConfigState.defaults.quiz.copyWith(lives: 0),
            ),
          );

      await container.read(gameConfigAutoSaveProvider.notifier).flushPendingSave();

      expect(
        capturedRequests.where(
          (r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/game_config.json',
        ),
        isEmpty,
      );
      expect(
        container.read(gameConfigAutoSaveProvider),
        GameConfigSaveStatus.error,
      );
    });
  });
}
