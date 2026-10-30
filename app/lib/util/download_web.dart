import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Offers the text as a file download, the browser way: a blob URL and a
/// click on a temporary anchor. Declaring UTF-8 keeps the naira sign
/// intact in whatever the rider saves.
void saveTextDownload(String filename, String text) {
  final blob = web.Blob(
    <JSAny>[text.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
