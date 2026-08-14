import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/game_config_models.dart';
import '../../data/services/asset_server_client.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';

class GameConfigNotifier extends StateNotifier<GameConfigState> {
  GameConfigNotifier([GameConfigState? initialState])
      : super(initialState ?? GameConfigState.defaults);

  void importContent(GameConfigState newState) {
    state = newState;
  }

  Future<void> loadFromServer(AssetServerClient client) async {
    try {
      final jsonString = await client.getFileAsString('data/game_config.json');
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final loadedState = GameConfigState.fromJson(jsonMap);
      if (mounted) {
        state = loadedState;
      }
    } on AssetServerException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) {
          state = GameConfigState.defaults;
        }
      } else {
        rethrow;
      }
    }
  }
}

final gameConfigProvider =
    StateNotifierProvider<GameConfigNotifier, GameConfigState>(
  (ref) => GameConfigNotifier(),
);

enum GameConfigLoadStatus { idle, loading, loaded, failed }

class GameConfigLoadNotifier extends StateNotifier<GameConfigLoadStatus> {
  GameConfigLoadNotifier(this._ref) : super(GameConfigLoadStatus.idle) {
    _listenForConnection();
  }

  final Ref _ref;
  bool _hasLoadedOnce = false;

  void _listenForConnection() {
    final currentConnectivity = _ref.read(serverConnectivityProvider);
    if (currentConnectivity == ServerConnectivity.connected && !_hasLoadedOnce) {
      _performLoad();
      return;
    }

    _ref.listen<ServerConnectivity>(
      serverConnectivityProvider,
      (previous, next) {
        if (next == ServerConnectivity.connected && !_hasLoadedOnce) {
          _performLoad();
        }
      },
    );
  }

  Future<void> performLoad() async {
    await _performLoad();
  }

  Future<void> _performLoad() async {
    if (state == GameConfigLoadStatus.loading) return;

    state = GameConfigLoadStatus.loading;

    try {
      final client = _ref.read(assetServerClientProvider);
      final notifier = _ref.read(gameConfigProvider.notifier);

      await notifier.loadFromServer(client);

      _hasLoadedOnce = true;

      if (mounted) {
        state = GameConfigLoadStatus.loaded;
      }
    } catch (_) {
      if (mounted) {
        state = GameConfigLoadStatus.failed;
      }
    }
  }
}

final gameConfigLoadProvider =
    StateNotifierProvider<GameConfigLoadNotifier, GameConfigLoadStatus>(
  (ref) => GameConfigLoadNotifier(ref),
);
