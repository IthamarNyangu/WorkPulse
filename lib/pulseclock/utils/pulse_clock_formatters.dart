String weekdayName(DateTime now) {
  const List<String> weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return weekdayNames[now.weekday - 1];
}

String dateLabel(DateTime now) {
  const List<String> monthAbbreviations = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${_twoDigits(now.day)} ${monthAbbreviations[now.month - 1]} ${now.year}';
}

String timeLabel(DateTime now) {
  final int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final String period = now.hour >= 12 ? 'PM' : 'AM';
  return '${_twoDigits(hour)}:${_twoDigits(now.minute)} $period';
}

String durationLabel(Duration duration) {
  final int totalMinutes = duration.inMinutes < 0 ? 0 : duration.inMinutes;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
