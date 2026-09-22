String formatDraftWhen(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final time = '${_two(local.hour)}:${_two(local.minute)}';
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(current.year, current.month, current.day);
  if (day == today) {
    return 'сегодня, $time';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'вчера, $time';
  }
  return '${_two(local.day)}.${_two(local.month)}.${local.year}, $time';
}

String _two(int value) => value.toString().padLeft(2, '0');
