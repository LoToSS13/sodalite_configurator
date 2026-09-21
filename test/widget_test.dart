import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/strings.dart';

void main() {
  testWidgets('home offers create module', (tester) async {
    await tester.pumpWidget(const ConfiguratorApp(download: _unusedDownload));

    expect(find.text(UiStrings.createModule), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
