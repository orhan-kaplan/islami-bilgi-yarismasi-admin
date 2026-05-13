import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../presentation/widgets/preview/preview_helpers.dart';
import '../models/feedback_models.dart';

/// Cihaz önizleme isteğinin sonucunu temsil eden sealed class.
///
/// Üç olası sonuç:
/// - [PreviewResultSuccess]: İstek başarıyla gönderildi (HTTP 200)
/// - [PreviewResultConnectionError]: Sunucuya bağlanılamadı (timeout/connection error)
/// - [PreviewResultServerError]: Sunucu hata yanıtı döndürdü (4xx/5xx)
sealed class PreviewResult {}

/// İstek başarıyla gönderildi.
class PreviewResultSuccess extends PreviewResult {}

/// Sunucuya bağlanılamadı (timeout veya connection error).
class PreviewResultConnectionError extends PreviewResult {}

/// Sunucu hata yanıtı döndürdü (4xx/5xx).
class PreviewResultServerError extends PreviewResult {
  /// Sunucudan gelen hata mesajı.
  final String message;

  PreviewResultServerError(this.message);
}

/// Admin aracından asset sunucuya preview isteği gönderen servis.
///
/// Feedback mesajını ve ekran bağlamını JSON formatında
/// `http://localhost:8080/api/preview` endpoint'ine POST eder.
///
/// [client] parametresi test ortamında HTTP çağrılarını mock'lamak için
/// kullanılabilir. Verilmezse varsayılan `http.Client()` kullanılır.
class DevicePreviewService {
  /// Opsiyonel HTTP client — test ortamında mock'lamak için.
  final http.Client _client;
  final bool _ownsClient;

  /// Preview endpoint URL'i.
  static const String _previewUrl = 'http://localhost:8080/api/preview';

  /// İstek timeout süresi.
  static const Duration _timeout = Duration(seconds: 5);

  /// Yeni bir [DevicePreviewService] oluşturur.
  ///
  /// [client] verilmezse varsayılan `http.Client()` kullanılır.
  DevicePreviewService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Feedback mesajını ve ekran bağlamını asset sunucuya gönderir.
  ///
  /// [message]: Önizlenecek feedback mesajı
  /// [screenContext]: Hedef ekran bağlamı (quizResult, dashboard, learnedResult)
  /// [category]: Feedback kategorisi (quiz, speed_quiz, time, comeback, streak, learned)
  /// [subcategory]: Alt kategori (opsiyonel)
  ///
  /// Döndürülen [PreviewResult]:
  /// - [PreviewResultSuccess]: HTTP 200 yanıtı alındı
  /// - [PreviewResultConnectionError]: Bağlantı hatası veya timeout
  /// - [PreviewResultServerError]: HTTP 4xx/5xx yanıtı
  Future<PreviewResult> sendPreview({
    required FeedbackMessageModel message,
    required PreviewContext screenContext,
    required String category,
    String? subcategory,
  }) async {
    final payload = _buildPayload(
      message: message,
      screenContext: screenContext,
      category: category,
      subcategory: subcategory,
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_previewUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return PreviewResultSuccess();
      }

      // 4xx/5xx server error
      final errorMessage = _extractErrorMessage(response);
      return PreviewResultServerError(errorMessage);
    } on TimeoutException {
      return PreviewResultConnectionError();
    } on http.ClientException {
      return PreviewResultConnectionError();
    } catch (_) {
      // Catch-all for any other connection-related errors
      return PreviewResultConnectionError();
    }
  }

  /// JSON payload'ını oluşturur.
  Map<String, dynamic> _buildPayload({
    required FeedbackMessageModel message,
    required PreviewContext screenContext,
    required String category,
    String? subcategory,
  }) {
    return {
      'title': message.title,
      'message': message.message,
      'emoji': message.emoji,
      'lottieAsset': message.lottieAsset,
      'shouldRepeat': message.shouldRepeat,
      'screenContext': screenContext.name,
      'category': category,
      'subcategory': subcategory,
    };
  }

  /// Sunucu hata yanıtından mesajı çıkarır.
  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error'] as String? ??
          'Sunucu hatası (${response.statusCode})';
    } catch (_) {
      return 'Sunucu hatası (${response.statusCode})';
    }
  }

  /// Kaynakları serbest bırakır.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
