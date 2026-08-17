import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/core/constants/asset_server_config.dart';

void main() {
  group('AssetServerConfig.fileUrl', () {
    test('göreli yolu api/files altına bağlar', () {
      expect(
        AssetServerConfig.fileUrl('images/book_1/cover.png'),
        '${AssetServerConfig.baseUrl}/api/files/images/book_1/cover.png',
      );
    });

    test('baştaki eğik çizgiyi çift slash üretmeden yutar', () {
      expect(
        AssetServerConfig.fileUrl('/lottie/confetti.json'),
        '${AssetServerConfig.baseUrl}/api/files/lottie/confetti.json',
      );
    });

    test('cacheBuster verilirse ?t= eklenir', () {
      expect(
        AssetServerConfig.fileUrl('images/a.png', cacheBuster: 42),
        '${AssetServerConfig.baseUrl}/api/files/images/a.png?t=42',
      );
    });

    test('cacheBuster null ise sorgu parametresi eklenmez', () {
      expect(
        AssetServerConfig.fileUrl('images/a.png'),
        isNot(contains('?')),
      );
    });
  });

  group('endpoint adresleri', () {
    test('health, preview ve sync-pubspec aynı kökten türer', () {
      expect(
        AssetServerConfig.healthUrl,
        '${AssetServerConfig.baseUrl}/api/health',
      );
      expect(
        AssetServerConfig.previewUrl,
        '${AssetServerConfig.baseUrl}/api/preview',
      );
      expect(
        AssetServerConfig.syncPubspecUrl,
        '${AssetServerConfig.baseUrl}/api/sync-pubspec',
      );
    });

    test('listUrl dizin yolunu api/list altına bağlar', () {
      expect(
        AssetServerConfig.listUrl('data/content'),
        '${AssetServerConfig.baseUrl}/api/list/data/content',
      );
    });

    test('baseUrl sondaki eğik çizgi içermez', () {
      expect(AssetServerConfig.baseUrl, isNot(endsWith('/')));
    });
  });

  group('cache-buster', () {
    test('now artan bir zaman damgası üretir', () {
      final first = AssetServerConfig.now;
      expect(first, greaterThan(0));
      expect(AssetServerConfig.now, greaterThanOrEqualTo(first));
    });
  });
}
