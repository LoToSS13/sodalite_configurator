import 'package:sodalite_configurator/schema/node_type.dart';

class Catalog {
  final Map<String, NodeType> types;

  const Catalog(this.types);

  NodeType type(String id) {
    final nodeType = types[id];
    if (nodeType == null) {
      throw StateError('Unknown node type: $id');
    }
    return nodeType;
  }

  static Catalog empty() => const Catalog({});
}
