import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_load_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';

ContentState _quizState() {
  return const ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Series',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: 'A',
      ),
    ],
    books: [],
    contentFiles: {},
    rewards: [],
    hadiths: [],
  );
}

FeedbackContentState _validFeedback() {
  FeedbackMessageModel msg(String title) => FeedbackMessageModel(
        title: title,
        message: 'Test message',
        emoji: '🎉',
        shouldRepeat: true,
      );

  return FeedbackContentState(
    quiz: {
      'speed_demon': [msg('Speed')],
      'perfect': [msg('Perfect')],
      'one_wrong': [msg('One Wrong')],
      'two_wrong': [msg('Two Wrong')],
      'good': [msg('Good')],
      'moderate': [msg('Moderate')],
      'failure': [msg('Failure')],
    },
    speedQuiz: {
      'combo_master': [msg('Combo')],
      'high_score': [msg('High')],
      'time_expired': [msg('Expired')],
      'moderate': [msg('Moderate')],
      'low': [msg('Low')],
    },
    time: {
      'seher': [msg('Seher')],
      'morning': [msg('Morning')],
      'noon': [msg('Noon')],
      'afternoon': [msg('Afternoon')],
      'evening': [msg('Evening')],
      'night': [msg('Night')],
      'teheccud': [msg('Teheccud')],
    },
    comeback: [msg('Comeback')],
    streak: {
      '3': [msg('3 days')],
    },
    titles: const [
      PlayerTitleModel(
        title: 'İlim Yolcusu',
        icon: '🌱',
        requiredBooks: 0,
        profileImage: 'images/seed/profile_icon_seed.webp',
      ),
    ],
    learned: {
      '100': [msg('100%')],
      '75': [msg('75%')],
      '50': [msg('50%')],
      '25': [msg('25%')],
      '0': [msg('0%')],
    },
  );
}

void main() {
  ProviderContainer createContainer({
    ContentState? content,
    List<Override> extraOverrides = const [],
  }) {
    final initial = content ?? ContentState.empty();
    final container = ProviderContainer(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: MockClient((_) async => http.Response('down', 500)),
          ),
        ),
        isServerConnectedProvider.overrideWithValue(false),
        serverConnectivityProvider.overrideWith(
          (ref) => _DisconnectedConnectivity(),
        ),
        autoLoadProvider.overrideWith((ref) => _AlreadyLoadedAutoLoad()),
        feedbackLoadProvider.overrideWith((ref) => _AlreadyLoadedFeedback()),
        gameConfigLoadProvider.overrideWith((ref) => _AlreadyLoadedGameConfig()),
        contentStateProvider.overrideWith((ref) => ContentNotifier(initial)),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('quiz content with no baseline is unsaved even though isDirty is false',
      () {
    const hadith = HadithModel(text: 'Yerel hadis', source: 'Kaynak');
    final container = createContainer(
      content: ContentState.empty().copyWith(hadiths: const [hadith]),
    );

    expect(container.read(savedBaselineProvider), isNull);
    expect(container.read(isDirtyProvider), isFalse);
    expect(container.read(hasUnsavedWorkProvider), isTrue);
  });

  test('queued content files are unsaved while the quiz baseline still matches',
      () {
    final state = _quizState();
    final container = createContainer(content: state);
    container.read(savedBaselineProvider.notifier).state = state;

    expect(container.read(isDirtyProvider), isFalse);

    container.read(autoSaveControllerProvider.notifier).queueAllFiles();

    expect(container.read(autoSaveControllerProvider.notifier).hasPendingSaves,
        isTrue);
    expect(container.read(isDirtyProvider), isFalse);
    expect(container.read(hasUnsavedWorkProvider), isTrue);
  });

  test('pending feedback write is unsaved while quiz isDirty is false', () {
    final container = createContainer();
    container.read(savedBaselineProvider.notifier).state = ContentState.empty();
    container.read(feedbackContentProvider.notifier).importContent(
          _validFeedback(),
        );
    container.read(feedbackAutoSaveProvider);

    container.read(feedbackContentProvider.notifier).addMessage(
          'comeback',
          null,
          const FeedbackMessageModel(
            title: 'Yeni',
            message: 'Yeni mesaj',
            emoji: 'N',
            shouldRepeat: true,
          ),
        );

    expect(container.read(isDirtyProvider), isFalse);
    expect(
      container.read(feedbackAutoSaveProvider.notifier).hasPendingChange,
      isTrue,
    );
    expect(container.read(hasUnsavedWorkProvider), isTrue);
  });

  test('pending game_config write is unsaved while quiz isDirty is false', () {
    final container = createContainer();
    container.read(savedBaselineProvider.notifier).state = ContentState.empty();
    container.read(gameConfigAutoSaveProvider);

    container.read(gameConfigProvider.notifier).importContent(
          GameConfigState.defaults.copyWith(
            quiz: GameConfigState.defaults.quiz.copyWith(lives: 4),
          ),
        );

    expect(container.read(isDirtyProvider), isFalse);
    expect(
      container.read(gameConfigAutoSaveProvider.notifier).hasPendingChange,
      isTrue,
    );
    expect(container.read(hasUnsavedWorkProvider), isTrue);
  });

  test('matching quiz baseline with no sidecar pending is not unsaved', () {
    final state = _quizState();
    final container = createContainer(content: state);
    container.read(savedBaselineProvider.notifier).state = state;
    container.read(autoSaveControllerProvider);
    container.read(feedbackAutoSaveProvider);
    container.read(gameConfigAutoSaveProvider);

    expect(container.read(isDirtyProvider), isFalse);
    expect(container.read(hasUnsavedWorkProvider), isFalse);
  });
}

class _DisconnectedConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _DisconnectedConnectivity() : super(ServerConnectivity.disconnected);
}

class _AlreadyLoadedAutoLoad extends StateNotifier<AutoLoadStatus>
    implements AutoLoadNotifier {
  _AlreadyLoadedAutoLoad() : super(AutoLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  bool get loadedFromServer => true;

  @override
  Future<void> performAutoLoad({bool force = false}) async {}

  @override
  void markSessionLoaded() {}

  @override
  void markSyncedToServer() {}
}

class _AlreadyLoadedFeedback extends StateNotifier<FeedbackLoadStatus>
    implements FeedbackLoadNotifier {
  _AlreadyLoadedFeedback() : super(FeedbackLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performLoad({bool force = false}) async {}

  @override
  void markLoaded() {}
}

class _AlreadyLoadedGameConfig extends StateNotifier<GameConfigLoadStatus>
    implements GameConfigLoadNotifier {
  _AlreadyLoadedGameConfig() : super(GameConfigLoadStatus.loaded);

  @override
  Future<void> performLoad({bool force = false}) async {}

  @override
  void markLoaded() {}
}
