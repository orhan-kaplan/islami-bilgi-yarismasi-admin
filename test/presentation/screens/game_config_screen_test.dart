import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/game_config/game_config_screen.dart';

/// Yükleme durumunu doğrudan `loaded`'a sabitler; ekran ağ beklemesin.
class _LoadedGameConfigNotifier extends GameConfigLoadNotifier {
  _LoadedGameConfigNotifier(super.ref) {
    state = GameConfigLoadStatus.loaded;
  }

  @override
  Future<void> performLoad({bool force = false}) async {}
}

void main() {
  const blockedErrorHeader = 'Saving is blocked — fix these errors:';

  Widget app({
    GameConfigState? initial,
    bool connected = true,
    ThemeData? theme,
    void Function(ProviderContainer)? onContainer,
  }) {
    return ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(connected),
        gameConfigProvider.overrideWith(
          (ref) => GameConfigNotifier(initial ?? GameConfigState.defaults),
        ),
        gameConfigLoadProvider.overrideWith(
          (ref) => _LoadedGameConfigNotifier(ref),
        ),
      ],
      child: Builder(
        builder: (context) {
          onContainer?.call(ProviderScope.containerOf(context));
          return MaterialApp(
            theme: theme,
            home: const GameConfigScreen(),
          );
        },
      ),
    );
  }

  /// Çok sayıda validasyon hatası üreten bir konfigürasyon.
  GameConfigState deeplyInvalid() {
    const base = GameConfigState.defaults;
    return base.copyWith(
      quiz: base.quiz.copyWith(
        lives: 0,
        pointsPerCorrect: 0,
        speedDemonMaxSecondsPerQuestion: 0,
        speedDemonMinAccuracy: 5,
        perfectMinAccuracy: 5,
        oneWrongCount: 0,
        twoWrongCount: 0,
        goodMinAccuracy: 5,
      ),
      speedQuiz: base.speedQuiz.copyWith(
        durationSeconds: 0,
        comboMinCombo: 0,
        comboMinAccuracy: 5,
        timeExpiredMaxAccuracy: 5,
        moderateMinAccuracy: 5,
      ),
      comebackMinDays: 0,
      dailyGoal: base.dailyGoal.copyWith(targetLevels: 0, targetQuestions: 0),
    );
  }

  /// ID6 — parse edilemeyen giriş sessizce yutuluyordu: alan yeni değeri
  /// gösteriyor, state eski değerinde kalıyor, kullanıcıya hiçbir şey
  /// söylenmiyordu.
  group('invalid numeric input is reported, not swallowed', () {
    testWidgets('a non-numeric value shows an error and keeps the old value',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(app(onContainer: (c) => container = c));
      await tester.pumpAndSettle();

      final before = container.read(gameConfigProvider).quiz.lives;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lives'),
        'abc',
      );
      await tester.pumpAndSettle();

      expect(container.read(gameConfigProvider).quiz.lives, before);
      expect(
        find.textContaining('Whole number expected'),
        findsOneWidget,
        reason: 'yutulan giriş kullanıcıya bildirilmeli',
      );
    });

    testWidgets('clearing a numeric field is reported', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Lives'), '');
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a value'), findsOneWidget);
    });

    testWidgets('an out-of-range clock value is reported', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(app(onContainer: (c) => container = c));
      await tester.pumpAndSettle();

      // Form lazy bir ListView: saat dilimi bölümü kaydırılınca inşa edilir.
      final field = find.widgetWithText(TextFormField, 'Start (HH:mm)');
      for (var i = 0; i < 40 && field.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(field, findsWidgets);

      final before = container.read(gameConfigProvider).timeSlots.first;
      await tester.enterText(field.first, '25:00');
      await tester.pumpAndSettle();

      expect(container.read(gameConfigProvider).timeSlots.first, before);
      expect(find.textContaining('Use HH:mm'), findsOneWidget);
    });

    testWidgets('a valid value still writes through and clears the error',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(app(onContainer: (c) => container = c));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lives'),
        'abc',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Whole number expected'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Lives'), '7');
      await tester.pumpAndSettle();

      expect(container.read(gameConfigProvider).quiz.lives, 7);
      expect(find.textContaining('Whole number expected'), findsNothing);
    });
  });

  /// ID8 — hata banner'ı `Column`'un esnek olmayan çocuğuydu; birkaç alan
  /// bozulunca kısa pencerede formu ezip taşıyordu.
  testWidgets('the blocked-save banner scrolls instead of overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(900, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(initial: deeplyInvalid()));
    await tester.pumpAndSettle();

    expect(find.text(blockedErrorHeader), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Form hâlâ kullanılabilir olmalı — banner ekranı yutmamalı.
    expect(find.byType(TextFormField), findsWidgets);
  });

  /// ID9 — banner sabit `Colors.red.shade50` kullanıyordu; koyu temada açık
  /// pembe zemin üstünde açık metin okunmuyordu.
  testWidgets('the blocked-save banner uses theme error tokens',
      (tester) async {
    final dark = ThemeData.dark(useMaterial3: true);
    await tester.pumpWidget(app(initial: deeplyInvalid(), theme: dark));
    await tester.pumpAndSettle();

    final banner = tester.widget<Material>(
      find
          .ancestor(
            of: find.text(blockedErrorHeader),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(banner.color, dark.colorScheme.errorContainer);
    expect(banner.color, isNot(Colors.red.shade50));

    final header = tester.widget<Text>(find.text(blockedErrorHeader));
    expect(
      header.style?.color,
      dark.colorScheme.onErrorContainer,
      reason: 'metin zemine göre okunabilir token almalı',
    );
  });

  /// ID10 — bağlantı kopunca auto-save sessizce atlıyor ama chip yeşil
  /// "Kaydedildi"de donuyordu.
  group('the save chip never claims "Saved" while offline', () {
    testWidgets('shows Offline when disconnected', (tester) async {
      await tester.pumpWidget(app(connected: false));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsNothing);
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('shows an unsaved warning after editing while offline',
        (tester) async {
      await tester.pumpWidget(app(connected: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Lives'), '4');
      await tester.pumpAndSettle();

      expect(find.text('Offline — not saved'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
    });
  });

  /// ID23 — admin arayüzü İngilizce (CLAUDE.md; app_shell_test aynı kuralı
  /// NavigationRail için zaten kilitliyor, ekranın kendi başlığı "Oyun"du).
  testWidgets('GameConfigScreen chrome is English', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Game Config'), findsOneWidget);
    for (final turkish in [
      'Oyun',
      'Hazır',
      'Can (lives)',
      'Hızlı Quiz',
      'Metinler',
      'Saat dilimleri (dashboard başlığı)',
    ]) {
      expect(find.text(turkish), findsNothing, reason: '$turkish Türkçe kaldı');
    }
    expect(find.widgetWithText(TextFormField, 'Lives'), findsOneWidget);
  });
}
