bool looksLikeHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

String _stripTrailingSlash(String value) => value.trim().replaceAll(RegExp(r'/+$'), '');

String consulAgentRoot(String value) {
  final text = _stripTrailingSlash(value);
  if (text.endsWith('/v1')) return text.substring(0, text.length - 3);
  return text;
}

String identityServerRoot(String value) {
  final uri = Uri.parse(value.trim());
  var path = _stripTrailingSlash(uri.path);
  for (final suffix in const ['/connect/authorize', '/connect/token', '/connect']) {
    if (path.endsWith(suffix)) {
      path = path.substring(0, path.length - suffix.length);
      break;
    }
  }
  return _stripTrailingSlash(uri.replace(path: path, query: '', fragment: '').toString());
}

/// API prefix that already ends with `/api/v1`.
String jasperApiPrefix(String value) {
  final uri = Uri.parse(value.trim());
  var path = _stripTrailingSlash(uri.path);
  if (path.endsWith('/XSDs')) path = path.substring(0, path.length - '/XSDs'.length);
  final root = _stripTrailingSlash(uri.replace(path: path, query: '', fragment: '').toString());
  if (root.endsWith('/api/v1')) return root;
  return '$root/api/v1';
}
