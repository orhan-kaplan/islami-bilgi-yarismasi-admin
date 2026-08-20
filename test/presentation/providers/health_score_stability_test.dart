import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/validation_providers.dart';

/// The missing-asset check re-runs on every content mutation. While it is
/// re-running, its warnings must not drop out of the combined result — the
/// health score is derived from that list and would jump on every keystroke.
void main() {
  group('healthScoreProvider formula', () {
    ValidationIssue issue(ValidationSeverity severity) => ValidationIssue(
          severity: severity,
          sourceFile: 'series.json',
          jsonPath: r'$',
          message: 'test issue',
        );

    double scoreFor({int errors = 0, int warnings = 0}) {
      final container = ProviderContainer(
        overrides: [
          allValidationResultsProvider.overrideWithValue([
            ...List.generate(errors, (_) => issue(ValidationSeverity.error)),
            ...List.generate(
                warnings, (_) => issue(ValidationSeverity.warning)),
          ]),
        ],
      );
      addTearDown(container.dispose);
      return container.read(healthScoreProvider);
    }

    test('no errors and no warnings scores 100', () {
      expect(scoreFor(), 100.0);
    });

    test('each error subtracts 10', () {
      expect(scoreFor(errors: 3), 70.0);
    });

    test('each warning subtracts 2', () {
      expect(scoreFor(warnings: 5), 90.0);
    });

    test('errors and warnings combine', () {
      // 2 errors * 10 + 4 warnings * 2 = 28
      expect(scoreFor(errors: 2, warnings: 4), 72.0);
    });

    test('score never drops below 0', () {
      // 20 errors * 10 = 200, far past 100 — must clamp, not go negative.
      expect(scoreFor(errors: 20), 0.0);
    });
  });

  BookModel book({required String title}) => BookModel(
        id: 1,
        title: title,
        description: 'Desc',
        assetImage: 'assets/images/book_1/cover.webp',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );

  ContentState stateWith(BookModel b) => ContentState(
        series: const [],
        books: [b],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      );

  test('missing-asset warnings survive a content edit', () async {
    // Directory exists but is empty, so the referenced cover is missing.
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode(const []), 200);
    });

    final container = ProviderContainer(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
        contentStateProvider.overrideWith(
          (ref) => ContentNotifier(stateWith(book(title: 'Book 1'))),
        ),
        isServerConnectedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    // Keep the combined result alive so it observes the reload.
    final sub = container.listen(allValidationResultsProvider, (_, _) {});
    addTearDown(sub.close);

    int missingAssetWarnings() => container
        .read(allValidationResultsProvider)
        .where((i) => i.message.contains('Asset not found'))
        .length;

    await container.read(missingAssetValidationProvider.future);
    expect(missingAssetWarnings(), 1);
    final scoreBefore = container.read(healthScoreProvider);

    // Editing content invalidates the async check; until it resolves again
    // the warning it already found is still the best answer we have.
    container
        .read(contentStateProvider.notifier)
        .updateBook(book(title: 'Book 1 renamed'));

    expect(
      missingAssetWarnings(),
      1,
      reason: 'the warning must not disappear while the check re-runs',
    );
    expect(container.read(healthScoreProvider), scoreBefore);
  });
}
