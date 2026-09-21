import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

Map<String, dynamic> encodeApp(Node app) => {
  'title': app.fields['title'] ?? '',
  'subtitle': app.fields['subtitle'] ?? '',
};

Node decodeApp(Map<String, dynamic> json, {required String id}) {
  return Node(id: id, typeId: TypeIds.app, fields: {'title': json['title'] ?? '', 'subtitle': json['subtitle'] ?? ''});
}
