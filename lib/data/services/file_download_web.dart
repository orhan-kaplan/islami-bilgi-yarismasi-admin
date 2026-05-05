import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of the given bytes with the specified filename.
///
/// Creates a Blob from the bytes, generates an object URL, creates an anchor
/// element with the download attribute, triggers a click, and revokes the URL.
void downloadFile(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();

  // Clean up
  web.document.body?.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}
