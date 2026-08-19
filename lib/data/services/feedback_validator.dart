// The feedback schema validation that gates `data/feedback.json` lives in
// `presentation/providers/feedback_content_providers.dart`; a second copy used
// to sit here, tested but wired to nothing.

/// Short lottie path relative to `assets/lottie/`.
/// Accepts `feedback/foo.json` and root files like `trophy_2.json`.
/// Rejects App_Path prefixes (`assets/...`) and parent-directory traversal.
bool isValidLottieShortPath(String? asset) {
  if (asset == null || asset.isEmpty) return true;
  if (asset.startsWith('assets/')) return false;
  if (asset.startsWith('/')) return false;
  if (asset.contains('..')) return false;
  return true;
}
