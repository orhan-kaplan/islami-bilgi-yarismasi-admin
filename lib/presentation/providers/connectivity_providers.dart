import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_server_providers.dart';

// =============================================================================
// Server Connectivity State
// =============================================================================

/// Represents the connectivity state of the asset server.
enum ServerConnectivity { connected, disconnected }

// =============================================================================
// Server Connectivity Notifier
// =============================================================================

/// Polls `/api/health` every 30 seconds to monitor asset server availability.
///
/// Starts with [ServerConnectivity.disconnected] and immediately performs
/// a health check on creation. Uses a 5-second timeout (configured in
/// [AssetServerClient]) to determine connectivity.
class ServerConnectivityNotifier extends StateNotifier<ServerConnectivity> {
  ServerConnectivityNotifier(this._ref)
      : super(ServerConnectivity.disconnected) {
    _checkHealth();
    _timer = Timer.periodic(_pollInterval, (_) => _checkHealth());
  }

  final Ref _ref;
  Timer? _timer;

  static const Duration _pollInterval = Duration(seconds: 30);

  /// Performs a single health check against the asset server.
  ///
  /// Sets state to [ServerConnectivity.connected] on success, or
  /// [ServerConnectivity.disconnected] on any error (timeout, network, non-200).
  Future<void> _checkHealth() async {
    try {
      final client = _ref.read(assetServerClientProvider);
      await client.health();
      if (mounted) {
        state = ServerConnectivity.connected;
      }
    } catch (_) {
      if (mounted) {
        state = ServerConnectivity.disconnected;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider for the server connectivity notifier that polls `/api/health`.
final serverConnectivityProvider =
    StateNotifierProvider<ServerConnectivityNotifier, ServerConnectivity>(
  (ref) => ServerConnectivityNotifier(ref),
);

/// Whether the asset server is currently reachable.
final isServerConnectedProvider = Provider<bool>((ref) {
  return ref.watch(serverConnectivityProvider) == ServerConnectivity.connected;
});
