@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/main.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_load_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/router/app_router.dart';

void main() {
  group('AdminApp eager auto-save init', () {
    MockClient failingClient() {
      return MockClient((request) async {
        return http.Response('unavailable', 500);
      });
    }

    GoRouter dummyRouter() {
      return GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    test('container alone does not initialize auto-save providers', () {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: failingClient(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.exists(autoSaveControllerProvider), isFalse);
      expect(container.exists(feedbackAutoSaveProvider), isFalse);
      expect(container.exists(gameConfigAutoSaveProvider), isFalse);
      expect(container.exists(autoLoadProvider), isFalse);
      expect(container.exists(serverConnectivityProvider), isFalse);
    });

    testWidgets('AdminApp watches auto-save providers on first build',
        (tester) async {
      final router = dummyRouter();
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: failingClient(),
            ),
          ),
          routerProvider.overrideWithValue(router),
          serverConnectivityProvider.overrideWith(
            (ref) => _DisconnectedConnectivity(),
          ),
          autoLoadProvider.overrideWith(
            (ref) => _IdleAutoLoad(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AdminApp(),
        ),
      );

      expect(container.exists(autoSaveControllerProvider), isTrue);
      expect(container.exists(feedbackAutoSaveProvider), isTrue);
      expect(container.exists(gameConfigAutoSaveProvider), isTrue);
      expect(container.exists(autoLoadProvider), isTrue);
      expect(container.exists(serverConnectivityProvider), isTrue);
    });
  });
}

class _DisconnectedConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _DisconnectedConnectivity() : super(ServerConnectivity.disconnected);
}

class _IdleAutoLoad extends StateNotifier<AutoLoadStatus>
    implements AutoLoadNotifier {
  _IdleAutoLoad() : super(AutoLoadStatus.idle);

  @override
  bool get hasLoadedOnce => false;

  @override
  Future<void> performAutoLoad() async {}
}
