import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ses önizlemesi için ince bir sarmalayıcı.
///
/// Doğrudan `HTMLAudioElement` kullanmak, oynatmanın başarısız oluşunu
/// (404, desteklenmeyen format, tarayıcının autoplay engeli) görünmez
/// kılıyordu: `play()`'in döndürdüğü promise dinlenmediği için buton
/// kalıcı olarak "Pause" durumunda kalıyordu. Arayüz aynı zamanda
/// testlerin gerçek tarayıcı sesi olmadan durumu doğrulamasını sağlar.
abstract class AudioPlayback {
  /// [url]'i baştan çalar. Çalan başka bir şey varsa durdurulur.
  ///
  /// [onEnded] dosya bitince, [onError] oynatma başarısız olursa çağrılır.
  void play(
    String url, {
    required void Function() onEnded,
    required void Function(Object error) onError,
  });

  /// Duraklatılmış sesi bulunduğu yerden devam ettirir.
  void resume();

  /// Konumu koruyarak duraklatır.
  void pause();

  /// Oynatmayı bitirir ve elementi bırakır.
  void stop();
}

/// Tarayıcının `HTMLAudioElement`'i üzerinden çalan gerçek uygulama.
class WebAudioPlayback implements AudioPlayback {
  web.HTMLAudioElement? _element;

  @override
  void play(
    String url, {
    required void Function() onEnded,
    required void Function(Object error) onError,
  }) {
    stop();

    final element = web.HTMLAudioElement()..src = url;
    _element = element;

    void fail(Object error) {
      if (!identical(_element, element)) return;
      stop();
      onError(error);
    }

    element.onEnded.listen((_) {
      if (!identical(_element, element)) return;
      stop();
      onEnded();
    });
    element.onError.listen((_) => fail('playback error'));

    element.play().toDart.then<void>(
      (_) {},
      onError: (Object error) => fail(error),
    );
  }

  @override
  void resume() {
    final element = _element;
    if (element == null) return;
    element.play().toDart.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  void pause() => _element?.pause();

  @override
  void stop() {
    _element?.pause();
    _element = null;
  }
}
