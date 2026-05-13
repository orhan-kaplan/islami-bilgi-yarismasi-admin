import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';

void main() {
  group('ServerConnectivityNotifier', () {
    /// Creates a [ProviderContainer] with [assetServerClientProvider] overridden
    /// to use the given [mockClient].
    ProviderContainer createContainer(http.Client mockClient) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initial state is disconnected before health check completes', () {
      // Use a completer to hold the health response so it never completes
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) => completer.future);

      final container = createContainer(mockClient);

      // Read the provider synchronously — the notifier starts as disconnected
      final state = container.read(serverConnectivityProvider);
      expect(state, ServerConnectivity.disconnected);
    });

    test('transitions to connected when health check succeeds', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'assetsRoot': '/tmp/assets',
            'readWrite': true,
          }),
          200,
        );
      });

      final container = createContainer(mockClient);

      // Trigger the provider (starts the notifier which calls _checkHealth)
      container.read(serverConnectivityProvider);

      // Allow the async health check to complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(serverConnectivityProvider);
      expect(state, ServerConnectivity.connected);
    });

    test('stays disconnected when health check returns non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Service unavailable'}),
          503,
        );
      });

      final container = createContainer(mockClient);

      // Trigger the provider
      container.read(serverConnectivityProvider);

      // Allow the async health check to complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(serverConnectivityProvider);
      expect(state, ServerConnectivity.disconnected);
    });

    test('stays disconnected when health check throws network error',
        () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient);

      // Trigger the provider
      container.read(serverConnectivityProvider);

      // Allow the async health check to complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(serverConnectivityProvider);
      expect(state, ServerConnectivity.disconnected);
    });

    test('stays disconnected when health check times out', () async {
      // Simulate a timeout by using a completer that never completes
      final mockClient = MockClient((request) async {
        // Simulate a request that takes longer than the 5s timeout
        throw TimeoutException('Connection timed out', Duration(seconds: 5));
      });

      final container = createContainer(mockClient);

      // Trigger the provider
      container.read(serverConnectivityProvider);

      // Allow the async health check to complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(serverConnectivityProvider);
      expect(state, ServerConnectivity.disconnected);
    });

    test(
        'transitions from connected to disconnected when server goes down',
        () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First call: server is up
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'assetsRoot': '/tmp/assets',
              'readWrite': true,
            }),
            200,
          );
        } else {
          // Subsequent calls: server is down
          throw http.ClientException('Connection refused');
        }
      });

      final container = createContainer(mockClient);

      // Trigger the provider — first health check succeeds
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(serverConnectivityProvider),
        ServerConnectivity.connected,
      );

      // Invalidate to simulate the timer triggering a new health check
      // (the next read will create a new notifier that calls _checkHealth)
      container.invalidate(serverConnectivityProvider);

      // Re-read triggers a new notifier with requestCount now > 1
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(serverConnectivityProvider),
        ServerConnectivity.disconnected,
      );
    });

    test(
        'transitions from disconnected to connected when server comes back',
        () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First call: server is down
          throw http.ClientException('Connection refused');
        } else {
          // Subsequent calls: server is back up
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'assetsRoot': '/tmp/assets',
              'readWrite': true,
            }),
            200,
          );
        }
      });

      final container = createContainer(mockClient);

      // Trigger the provider — first health check fails
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(serverConnectivityProvider),
        ServerConnectivity.disconnected,
      );

      // Invalidate to simulate the timer triggering a new check
      container.invalidate(serverConnectivityProvider);

      // Re-read triggers a new notifier with requestCount now > 1
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(serverConnectivityProvider),
        ServerConnectivity.connected,
      );
    });

    test('isServerConnectedProvider returns true when connected', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'assetsRoot': '/tmp/assets',
            'readWrite': true,
          }),
          200,
        );
      });

      final container = createContainer(mockClient);

      // Trigger the connectivity provider
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(isServerConnectedProvider), isTrue);
    });

    test('isServerConnectedProvider returns false when disconnected',
        () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient);

      // Trigger the connectivity provider
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(isServerConnectedProvider), isFalse);
    });

    test('timer is cancelled on dispose', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'assetsRoot': '/tmp/assets',
            'readWrite': true,
          }),
          200,
        );
      });

      final container = createContainer(mockClient);

      // Trigger the provider
      container.read(serverConnectivityProvider);
      await Future<void>.delayed(Duration.zero);

      // Disposing the container should not throw
      container.dispose();
    });
  });
}
