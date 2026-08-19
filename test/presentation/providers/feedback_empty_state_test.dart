import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

/// `feedback_screen.dart` içindeki "İlk Veriyi Oluştur" ile aynı şekil.
FeedbackContentState _initialData() {
  const msg = FeedbackMessageModel(
    title: 'Yeni Mesaj',
    message: 'Mesaj içeriği',
    emoji: '📝',
  );
  return const FeedbackContentState(
    quiz: {
      'speed_demon': [msg],
      'perfect': [msg],
      'one_wrong': [msg],
      'two_wrong': [msg],
      'good': [msg],
      'moderate': [msg],
      'failure': [msg],
    },
    speedQuiz: {
      'combo_master': [msg],
      'high_score': [msg],
      'time_expired': [msg],
      'moderate': [msg],
      'low': [msg],
    },
    time: {
      'seher': [msg],
      'morning': [msg],
      'noon': [msg],
      'afternoon': [msg],
      'evening': [msg],
      'night': [msg],
      'teheccud': [msg],
    },
    comeback: [msg],
    streak: {
      '3': [msg],
      '7': [msg],
      '30': [msg],
    },
    titles: [
      PlayerTitleModel(
        title: 'İlim Yolcusu',
        icon: '🌱',
        requiredBooks: 0,
        profileImage: '',
      ),
    ],
    learned: {
      '100': [msg],
      '75': [msg],
      '50': [msg],
      '25': [msg],
      '0': [msg],
    },
  );
}

/// feedback.json sunucuda yokken oluşan durum.
class _EmptyStatusNotifier extends StateNotifier<FeedbackLoadStatus>
    implements FeedbackLoadNotifier {
  _EmptyStatusNotifier() : super(FeedbackLoadStatus.empty);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performLoad() async {}

  @override
  void markLoaded() => state = FeedbackLoadStatus.loaded;
}

void main() {
  group('Feedback auto-save with no feedback.json on the server', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createEmptyContainer({required http.Client mockClient}) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          isServerConnectedProvider.overrideWithValue(true),
          feedbackLoadProvider.overrideWith((ref) => _EmptyStatusNotifier()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('initial data created from the empty state is written to the server',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createEmptyContainer(mockClient: mockClient);
      container.read(feedbackAutoSaveProvider);

      container
          .read(feedbackContentProvider.notifier)
          .importContent(_initialData());

      await container.read(feedbackAutoSaveProvider.notifier).flushPendingSave();

      final puts = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();
      expect(puts, isNotEmpty);
      expect(puts.last.body, contains('İlim Yolcusu'));
    });
  });

  group('FeedbackLoadNotifier.markLoaded', () {
    test('flips an empty status to loaded', () {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: MockClient((_) async => http.Response('Not found', 404)),
            ),
          ),
          serverConnectivityProvider.overrideWith(
            (ref) => _DisconnectedConnectivity(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.idle);

      container.read(feedbackLoadProvider.notifier).markLoaded();

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.loaded);
    });
  });
}

class _DisconnectedConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _DisconnectedConnectivity() : super(ServerConnectivity.disconnected);
}
