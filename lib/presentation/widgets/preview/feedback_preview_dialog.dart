import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../data/models/feedback_models.dart';
import '../../../data/services/device_preview_service.dart';
import 'dashboard_preview.dart';
import 'learned_result_preview.dart';
import 'phone_mockup_frame.dart';
import 'preview_helpers.dart';
import 'quiz_result_preview.dart';
import '../../../core/constants/asset_server_config.dart';

/// Ana önizleme dialog'unu gösterir.
///
/// Feedback mesajının mobil uygulamadaki görünümünü telefon mockup
/// çerçevesi içinde, seçilen ekran bağlamına göre render eder.
///
/// [httpClient] parametresi test ortamında HTTP çağrılarını mock'lamak için
/// kullanılabilir. Verilmezse varsayılan `http.Client()` kullanılır.
Future<void> showFeedbackPreviewDialog(
  BuildContext context, {
  required FeedbackMessageModel message,
  required String category,
  String? subcategory,
  http.Client? httpClient,
}) {
  return showDialog(
    context: context,
    builder: (context) => FeedbackPreviewDialog(
      message: message,
      category: category,
      subcategory: subcategory,
      httpClient: httpClient,
    ),
  );
}

/// Ana önizleme dialog widget'ı.
///
/// Telefon mockup + içerik render orkestratörü.
/// Ekran bağlamını kategori bazında otomatik belirler.
class FeedbackPreviewDialog extends StatefulWidget {
  const FeedbackPreviewDialog({
    super.key,
    required this.message,
    required this.category,
    this.subcategory,
    this.httpClient,
  });

  /// Önizlenecek feedback mesajı.
  final FeedbackMessageModel message;

  /// Kategori: 'quiz', 'speed_quiz', 'time', 'comeback', 'streak', 'learned'.
  final String category;

  /// Alt kategori (opsiyonel).
  final String? subcategory;

  /// Opsiyonel HTTP client — test ortamında mock'lamak için.
  final http.Client? httpClient;

  @override
  State<FeedbackPreviewDialog> createState() => _FeedbackPreviewDialogState();
}

class _FeedbackPreviewDialogState extends State<FeedbackPreviewDialog> {
  late final PreviewContext _context;
  bool _assetServerConnected = true;
  bool _checkingServer = true;
  bool _sendingPreview = false;

  @override
  void initState() {
    super.initState();
    _context = defaultContextForCategory(widget.category);
    _checkAssetServer();
  }

  Future<void> _checkAssetServer() async {
    final client = widget.httpClient;
    try {
      final uri = Uri.parse(AssetServerConfig.healthUrl);
      final response = client != null
          ? await client.get(uri).timeout(const Duration(seconds: 3))
          : await http.get(uri).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _assetServerConnected = response.statusCode == 200;
          _checkingServer = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assetServerConnected = false;
          _checkingServer = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button (top-right style)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Close',
                ),
              ),
              // Asset server warning banner
              if (!_checkingServer && !_assetServerConnected)
                _buildWarningBanner(),
              const SizedBox(height: 16),
              // Phone mockup with preview content
              PhoneMockupFrame(
                child: _buildPreviewContent(),
              ),
              const SizedBox(height: 16),
              // "Cihazda Test Et" button (disabled)
              _buildDeviceTestButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Text(
            'Asset server is not connected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (_context) {
      case PreviewContext.quizResult:
        return QuizResultPreview(
          message: widget.message,
          subcategory: widget.subcategory,
        );
      case PreviewContext.dashboard:
        return DashboardPreview(
          message: widget.message,
          category: widget.category,
          subcategory: widget.subcategory,
        );
      case PreviewContext.learnedResult:
        return LearnedQuizResultPreview(
          message: widget.message,
          subcategory: widget.subcategory,
        );
    }
  }

  Widget _buildDeviceTestButton() {
    final bool isDisabled = _checkingServer || !_assetServerConnected;

    // Sunucu kontrolü sürerken (3 saniyeye kadar) buton sebepsiz pasif
    // duruyordu: ne banner ne de tooltip nedenini söylüyordu.
    final String tooltip;
    if (_checkingServer) {
      tooltip = 'Checking the asset server…';
    } else if (!_assetServerConnected) {
      tooltip = 'Asset server is not connected — start it to test on a device';
    } else {
      tooltip = 'Sends the preview to the app running on the emulator';
    }

    return Tooltip(
      message: tooltip,
      child: FilledButton.icon(
        onPressed: isDisabled || _sendingPreview ? null : _sendDevicePreview,
        icon: _sendingPreview || _checkingServer
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : const Icon(Icons.phone_android),
        label: Text(_checkingServer ? 'Checking server…' : 'Test on device'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white24,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white38,
        ),
      ),
    );
  }

  Future<void> _sendDevicePreview() async {
    setState(() {
      _sendingPreview = true;
    });

    final service = DevicePreviewService(client: widget.httpClient);

    try {
      final result = await service.sendPreview(
        message: widget.message,
        screenContext: _context,
        category: widget.category,
        subcategory: widget.subcategory,
      );

      if (!mounted) return;

      switch (result) {
        case PreviewResultSuccess():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preview request sent')),
          );
        case PreviewResultConnectionError():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not reach the asset server. Make sure it is running.',
              ),
            ),
          );
        case PreviewResultServerError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingPreview = false;
        });
      }
      service.dispose();
    }
  }
}
