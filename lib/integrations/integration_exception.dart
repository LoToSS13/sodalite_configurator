class IntegrationException implements Exception {
  IntegrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String briefBody(String body) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return '';
  if (compact.length <= 180) return compact;
  return '${compact.substring(0, 180)}…';
}
