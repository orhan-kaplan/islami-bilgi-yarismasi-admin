import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_auto_save_providers.dart';

/// The shell's save-error dot must cover every auto-save channel. A write
/// blocked by validation is only reported through its status provider, so a
/// channel missing from this list fails silently once the user navigates away.
void main() {
  ProviderContainer containerWith({
    SaveStatus content = SaveStatus.idle,
    FeedbackSaveStatus feedback = FeedbackSaveStatus.idle,
    GameConfigSaveStatus gameConfig = GameConfigSaveStatus.idle,
  }) {
    final container = ProviderContainer(
      overrides: [
        saveStatusProvider.overrideWithValue(content),
        feedbackSaveStatusProvider.overrideWithValue(feedback),
        gameConfigSaveStatusProvider.overrideWithValue(gameConfig),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no error on any channel means no indicator', () {
    expect(containerWith().read(hasSaveErrorProvider), isFalse);
  });

  test('a blocked content save raises the indicator', () {
    expect(
      containerWith(content: SaveStatus.error).read(hasSaveErrorProvider),
      isTrue,
    );
  });

  test('a blocked feedback save raises the indicator', () {
    expect(
      containerWith(feedback: FeedbackSaveStatus.error)
          .read(hasSaveErrorProvider),
      isTrue,
    );
  });

  test('a blocked game_config save raises the indicator', () {
    expect(
      containerWith(gameConfig: GameConfigSaveStatus.error)
          .read(hasSaveErrorProvider),
      isTrue,
      reason: 'game_config.json is auto-saved and gated like the others; a '
          'validation-blocked write must be visible outside its own screen',
    );
  });
}
