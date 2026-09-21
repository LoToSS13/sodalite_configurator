import 'package:flutter/foundation.dart';

@immutable
class Issue {
  final String nodeId;
  final String path;
  final String message;

  const Issue({required this.nodeId, required this.path, required this.message});
}
