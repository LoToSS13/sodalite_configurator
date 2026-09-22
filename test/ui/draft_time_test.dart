import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/ui/draft_time.dart';

void main() {
  final now = DateTime(2026, 9, 22, 15, 4);

  test('formatDraftWhen uses today, yesterday, or a calendar date', () {
    expect(formatDraftWhen(DateTime(2026, 9, 22, 9, 5), now: now), 'сегодня, 09:05');
    expect(formatDraftWhen(DateTime(2026, 9, 21, 18, 40), now: now), 'вчера, 18:40');
    expect(formatDraftWhen(DateTime(2026, 1, 3, 7, 8), now: now), '03.01.2026, 07:08');
  });
}
