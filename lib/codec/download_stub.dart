void downloadBytes({required String filename, required List<int> bytes}) {
  throw UnsupportedError('Zip download is only supported in the browser ($filename, ${bytes.length} bytes)');
}
