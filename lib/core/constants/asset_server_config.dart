/// Asset server'ın adresi ve URL kurma yardımcıları.
///
/// Bu adres daha önce 16 dosyada string olarak tekrarlanıyordu; port çakışması
/// veya adres değişikliği her birine ayrı dokunmayı gerektiriyordu. Tüm URL
/// kurulumu buradan geçer.
///
/// Server'ı farklı bir portta çalıştırmak için build sırasında:
/// ```
/// flutter run -d chrome --dart-define=ASSET_SERVER_URL=http://localhost:9090
/// ```
class AssetServerConfig {
  const AssetServerConfig._();

  /// Server'ın kök adresi. Sondaki `/` içermez.
  static const String baseUrl = String.fromEnvironment(
    'ASSET_SERVER_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// `GET /api/health` — bağlantı kontrolü.
  static String get healthUrl => '$baseUrl/api/health';

  /// `GET/POST /api/preview` — cihaz önizleme kanalı.
  static String get previewUrl => '$baseUrl/api/preview';

  /// `POST /api/sync-pubspec` — mobil uygulamanın pubspec.yaml'ını günceller.
  static String get syncPubspecUrl => '$baseUrl/api/sync-pubspec';

  /// Assets kökünden göreli bir dosyanın URL'i.
  ///
  /// [cacheBuster] verilirse `?t=` parametresi eklenir — tarayıcı, üzerine
  /// yazılan görselleri önbellekten servis etmesin diye kullanılır. `null`
  /// ise parametre eklenmez.
  static String fileUrl(String path, {Object? cacheBuster}) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final url = '$baseUrl/api/files/$normalized';
    return cacheBuster == null ? url : '$url?t=$cacheBuster';
  }

  /// Bir dizinin listelenme URL'i (`GET /api/list/<path>`).
  static String listUrl(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/api/list/$normalized';
  }

  /// Şu anki zaman damgasından bir cache-buster üretir.
  static int get now => DateTime.now().millisecondsSinceEpoch;
}
