@TestOn('chrome')
library;

// Audio sekmesinin oynatma durumunu kilitler: çalmayan bir dosya butonu
// Pause'da dondurmamalı ve Pause gerçekten duraklatmalı (baştan başlatmamalı).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/audio_playback.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/assets/assets_screen.dart';

/// Tarayıcı ses elementinin yerine geçen, çağrıları kaydeden sahte oynatıcı.
class FakeAudioPlayback implements AudioPlayback {
  final List<String> calls = [];
  void Function()? _onEnded;
  void Function(Object error)? _onError;

  @override
  void play(
    String url, {
    required void Function() onEnded,
    required void Function(Object error) onError,
  }) {
    calls.add('play:$url');
    _onEnded = onEnded;
    _onError = onError;
  }

  @override
  void resume() => calls.add('resume');

  @override
  void pause() => calls.add('pause');

  @override
  void stop() => calls.add('stop');

  void fireError() => _onError?.call('NotSupportedError');

  void fireEnded() => _onEnded?.call();
}

void main() {
  const audioEntry = {
    'name': 'welcome.mp3',
    'path': 'audio/welcome.mp3',
    'size': 12345,
    'type': 'file',
    'modified': null,
  };

  Widget createTestWidget(FakeAudioPlayback player) {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/list/audio') {
        return http.Response(jsonEncode([audioEntry]), 200);
      }
      return http.Response(jsonEncode([]), 200);
    });

    return ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
        isServerConnectedProvider.overrideWithValue(true),
        audioPlaybackProvider.overrideWithValue(player),
      ],
      child: const MaterialApp(home: AssetsScreen()),
    );
  }

  Future<void> openAudioTab(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
  }

  group('AudioTab playback state', () {
    testWidgets('playback that fails releases the button instead of freezing',
        (tester) async {
      final player = FakeAudioPlayback();
      await tester.pumpWidget(createTestWidget(player));
      await openAudioTab(tester);

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

      player.fireError();
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.play_circle_filled),
        findsOneWidget,
        reason: 'a file that never played must not stay stuck on Pause',
      );
      expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
      expect(find.textContaining('Could not play welcome.mp3'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('reaching the end of a file resets the button',
        (tester) async {
      final player = FakeAudioPlayback();
      await tester.pumpWidget(createTestWidget(player));
      await openAudioTab(tester);

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pumpAndSettle();

      player.fireEnded();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('Pause resumes where it stopped instead of restarting',
        (tester) async {
      final player = FakeAudioPlayback();
      await tester.pumpWidget(createTestWidget(player));
      await openAudioTab(tester);

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pumpAndSettle();

      expect(
        player.calls,
        ['play:http://localhost:8080/api/files/audio/welcome.mp3', 'pause',
            'resume'],
        reason: 'the button says Pause, so it must not restart the track',
      );
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });
  });
}
