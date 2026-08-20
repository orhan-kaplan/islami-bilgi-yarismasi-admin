import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';

const _healthJson = '{"status": "ok", "assetsRoot": "/tmp/assets", "readWrite": true}';

void main() {
  group('GameConfigNotifier', () {
    test('starts from defaults', () {
      expect(GameConfigNotifier().state.toJson(), GameConfigState.defaults.toJson());
    });

    test('importContent replaces the in-memory state', () {
      final notifier = GameConfigNotifier();
      notifier.importContent(
        GameConfigState.fromJson({
          'quiz': {'lives': 4},
        }),
      );
      expect(notifier.state.quiz.lives, 4);
    });

    test('loadFromServer parses game_config.json', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/files/data/game_config.json') {
          return http.Response(
            jsonEncode({
              'quiz': {'lives': 5, 'points_per_correct': 20},
              'comeback': {'min_days': 8},
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final notifier = GameConfigNotifier();
      await notifier.loadFromServer(
        AssetServerClient(
          baseUrl: 'http://localhost:8080',
          client: mockClient,
        ),
      );

      expect(notifier.state.quiz.lives, 5);
      expect(notifier.state.quiz.pointsPerCorrect, 20);
      expect(notifier.state.comebackMinDays, 8);
    });

    test('404 keeps Dart defaults (does not wipe to empty)', () async {
      final notifier = GameConfigNotifier(
        GameConfigState.fromJson({
          'quiz': {'lives': 9},
        }),
      );

      await notifier.loadFromServer(
        AssetServerClient(
          baseUrl: 'http://localhost:8080',
          client: MockClient((request) async {
            return http.Response('{"error": "File not found"}', 404);
          }),
        ),
      );

      expect(notifier.state.quiz.lives, 3);
      expect(notifier.state.toJson(), GameConfigState.defaults.toJson());
    });

    test('rethrows non-404 AssetServerException', () async {
      final notifier = GameConfigNotifier();
      expect(
        () => notifier.loadFromServer(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: MockClient((request) async {
              return http.Response('{"error": "Internal error"}', 500);
            }),
          ),
        ),
        throwsA(isA<AssetServerException>()),
      );
    });
  });

  group('GameConfigLoadNotifier', () {
    ProviderContainer createContainer({
      required http.Client mockClient,
      List<Override> extraOverrides = const [],
    }) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          ...extraOverrides,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('performLoad transitions to loaded on success', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') return http.Response(_healthJson, 200);
        if (path == '/api/files/data/game_config.json') {
          return http.Response(jsonEncode({'quiz': {'lives': 5}}), 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(gameConfigLoadProvider.notifier);
      await notifier.performLoad();

      expect(
          container.read(gameConfigLoadProvider), GameConfigLoadStatus.loaded);
      expect(container.read(gameConfigProvider).quiz.lives, 5);
    });

    test('performLoad transitions to loaded (with defaults) on 404', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') return http.Response(_healthJson, 200);
        if (path == '/api/files/data/game_config.json') {
          return http.Response('{"error": "File not found"}', 404);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(gameConfigLoadProvider.notifier);
      await notifier.performLoad();

      expect(
          container.read(gameConfigLoadProvider), GameConfigLoadStatus.loaded);
      expect(
        container.read(gameConfigProvider).toJson(),
        GameConfigState.defaults.toJson(),
      );
    });

    test('performLoad transitions to failed on server error', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') return http.Response(_healthJson, 200);
        if (path == '/api/files/data/game_config.json') {
          return http.Response('{"error": "Internal error"}', 500);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(gameConfigLoadProvider.notifier);
      await notifier.performLoad();

      expect(
          container.read(gameConfigLoadProvider), GameConfigLoadStatus.failed);
    });

    test('performLoad transitions to failed on network error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(gameConfigLoadProvider.notifier);
      await notifier.performLoad();

      expect(
          container.read(gameConfigLoadProvider), GameConfigLoadStatus.failed);
    });

    test('auto-triggers when connectivity becomes connected', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') return http.Response(_healthJson, 200);
        if (path == '/api/files/data/game_config.json') {
          return http.Response(jsonEncode({'quiz': {'lives': 5}}), 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      // Reading the provider creates the notifier, which listens to
      // connectivity. The connectivity notifier's health check will
      // transition to connected, triggering the load.
      container.read(gameConfigLoadProvider);

      var status = container.read(gameConfigLoadProvider);
      var waited = Duration.zero;
      const step = Duration(milliseconds: 20);
      const maxWait = Duration(seconds: 2);
      while (status != GameConfigLoadStatus.loaded && waited < maxWait) {
        await Future<void>.delayed(step);
        waited += step;
        status = container.read(gameConfigLoadProvider);
      }

      expect(status, GameConfigLoadStatus.loaded);
    });

    test('performLoad keeps a non-default local config unless force is set',
        () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') return http.Response(_healthJson, 200);
        if (path == '/api/files/data/game_config.json') {
          return http.Response(jsonEncode({'quiz': {'lives': 5}}), 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(
        mockClient: mockClient,
        extraOverrides: [
          serverConnectivityProvider.overrideWith(
            (ref) => _DisconnectedConnectivity(),
          ),
        ],
      );

      container.read(gameConfigProvider.notifier).importContent(
            GameConfigState.fromJson({
              'quiz': {'lives': 9},
            }),
          );

      final notifier = container.read(gameConfigLoadProvider.notifier);
      await notifier.performLoad();

      expect(container.read(gameConfigProvider).quiz.lives, 9);
      expect(
        container.read(gameConfigLoadProvider),
        GameConfigLoadStatus.loaded,
      );

      await notifier.performLoad(force: true);
      expect(container.read(gameConfigProvider).quiz.lives, 5);
    });
  });
}

class _DisconnectedConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _DisconnectedConnectivity() : super(ServerConnectivity.disconnected);
}
