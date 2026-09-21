final RegExp _placeholderPattern = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

List<String> extractPlaceholders(String value) {
  return [for (final match in _placeholderPattern.allMatches(value)) match.group(1)!];
}
