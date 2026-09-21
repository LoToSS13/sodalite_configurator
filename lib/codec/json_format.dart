import 'dart:convert';

import 'package:flutter/foundation.dart';

String encodeJson(Object value) => const JsonEncoder.withIndent('  ').convert(value);

@immutable
class ImportWarning {
  final String file;
  final String message;

  const ImportWarning({required this.file, required this.message});
}
