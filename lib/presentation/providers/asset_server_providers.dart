import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/asset_server_client.dart';

/// Provider for the AssetServerClient instance.
///
/// Configured with default `http://localhost:8080` base URL.
/// Can be overridden in tests or for custom server configurations.
final assetServerClientProvider = Provider<AssetServerClient>((ref) {
  return AssetServerClient(baseUrl: 'http://localhost:8080');
});
