import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/placeholders.dart';

void main() {
  test('extracts valid placeholder identifiers', () {
    expect(extractPlaceholders('Hello {Name}, {_status2}: {Name}'), ['Name', '_status2', 'Name']);
  });

  test('ignores invalid and unmatched placeholders', () {
    expect(extractPlaceholders('{2Name} {with-dash} {with space} {Missing'), isEmpty);
  });
}
