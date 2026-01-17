const List<String> kWeekdayLabels = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayLabel(int weekday) {
  if (weekday < 1 || weekday >= kWeekdayLabels.length) {
    return 'Unknown';
  }
  return kWeekdayLabels[weekday];
}
