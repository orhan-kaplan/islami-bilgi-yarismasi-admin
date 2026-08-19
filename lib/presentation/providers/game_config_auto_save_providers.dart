import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/game_config_models.dart';
import '../../data/services/game_config_validator.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';
import 'game_config_providers.dart';

enum GameConfigSaveStatus { idle, saving, saved, error }

class GameConfigAutoSaveController extends StateNotifier<GameConfigSaveStatus> {
  GameConfigAutoSaveController(this._ref) : super(GameConfigSaveStatus.idle) {
    _init();
  }

  final Ref _ref;
  Timer? _debounceTimer;
  bool _hasPendingChange = false;

  static const Duration _debounceDuration = Duration(seconds: 2);

  void _init() {
    final loadStatus = _ref.read(gameConfigLoadProvider);
    if (loadStatus == GameConfigLoadStatus.loaded) {
      _startListening();
      return;
    }

    _ref.listen<GameConfigLoadStatus>(gameConfigLoadProvider, (previous, next) {
      if (next == GameConfigLoadStatus.loaded &&
          previous != GameConfigLoadStatus.loaded) {
        _startListening();
      }
    });
  }

  void _startListening() {
    _ref.listen<GameConfigState>(gameConfigProvider, (previous, next) {
      if (previous == null) return;
      _onContentChanged();
    });
  }

  /// Bağlantı yokken de pending işaretlenir; yazma [_saveFile] içinde yine
  /// bağlantıya bakar. Aksi halde bağlantı kopukken yapılan düzenleme hiç
  /// kuyruğa girmiyor, yeniden bağlanınca da kaydedilmiyordu.
  void _onContentChanged() {
    _hasPendingChange = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _saveFile();
    });
  }

  Future<void> _saveFile() async {
    _debounceTimer = null;

    if (!_ref.read(isServerConnectedProvider)) return;

    final contentState = _ref.read(gameConfigProvider);

    final errors = validateGameConfigData(contentState);
    if (errors.isNotEmpty) {
      _hasPendingChange = true;
      if (mounted) {
        state = GameConfigSaveStatus.error;
      }
      return;
    }

    _hasPendingChange = false;

    if (mounted) {
      state = GameConfigSaveStatus.saving;
    }

    try {
      final client = _ref.read(assetServerClientProvider);
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(contentState.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      await client.putFile('data/game_config.json', bytes);

      if (mounted) {
        state = GameConfigSaveStatus.saved;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && state == GameConfigSaveStatus.saved) {
            state = GameConfigSaveStatus.idle;
          }
        });
      }
    } catch (_) {
      // Yazım başarısız oldu: değişikliği kuyrukta tut, yoksa sonraki flush
      // "pending yok" diye hemen döner ve düzenleme tarayıcı belleğinde kalır.
      _hasPendingChange = true;
      if (mounted) {
        state = GameConfigSaveStatus.error;
      }
    }
  }

  Future<void> flushPendingSave() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (!_hasPendingChange) return;

    if (!_ref.read(isServerConnectedProvider)) return;

    await _saveFile();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _hasPendingChange = false;
    super.dispose();
  }
}

final gameConfigAutoSaveProvider =
    StateNotifierProvider<GameConfigAutoSaveController, GameConfigSaveStatus>(
  (ref) => GameConfigAutoSaveController(ref),
);
