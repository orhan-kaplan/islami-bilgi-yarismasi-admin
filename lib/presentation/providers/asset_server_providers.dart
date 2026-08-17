import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/asset_server_client.dart';
import '../../core/constants/asset_server_config.dart';

/// Provider for the AssetServerClient instance.
///
/// Base URL comes from AssetServerConfig (override with --dart-define).
/// Can be overridden in tests or for custom server configurations.
final assetServerClientProvider = Provider<AssetServerClient>((ref) {
  return AssetServerClient(baseUrl: AssetServerConfig.baseUrl);
});
