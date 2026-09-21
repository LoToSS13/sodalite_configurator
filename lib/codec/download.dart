import 'package:sodalite_configurator/codec/download_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/codec/download_web.dart'
    as impl;

typedef DownloadFn = void Function({required String filename, required List<int> bytes});

void downloadBytes({required String filename, required List<int> bytes}) {
  impl.downloadBytes(filename: filename, bytes: bytes);
}
