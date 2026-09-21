import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

void downloadBytes({required String filename, required List<int> bytes}) {
  final blob = Blob([Uint8List.fromList(bytes).toJS].toJS);
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}
