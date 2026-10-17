import 'package:intl/intl.dart';

String formatIndonesianDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd MMM yyyy, HH.mm', 'id_ID').format(date);
}

String formatIndonesianDateRange(DateTime start, DateTime end) {
  final formatter = DateFormat('d MMM yyyy', 'id_ID');
  return '${formatter.format(start)} - ${formatter.format(end)}';
}
