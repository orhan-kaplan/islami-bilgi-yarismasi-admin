import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';

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
}
