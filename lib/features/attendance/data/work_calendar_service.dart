import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkCalendarService {
  WorkCalendarService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String publicHolidaysTableName = 'public_holidays';

  final SupabaseClient _client;

  Future<Set<String>> fetchPublicHolidayDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final DateTime normalizedStart = _dateOnly(
      startDate.isAfter(endDate) ? endDate : startDate,
    );
    final DateTime normalizedEnd = _dateOnly(
      startDate.isAfter(endDate) ? startDate : endDate,
    );

    try {
      final List<dynamic> rows = await _client
          .from(publicHolidaysTableName)
          .select('holiday_date')
          .eq('is_active', true)
          .gte('holiday_date', _dateLabel(normalizedStart))
          .lte('holiday_date', _dateLabel(normalizedEnd));

      return rows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .map((Map<String, dynamic> row) => row['holiday_date'] as String?)
          .whereType<String>()
          .toSet();
    } on PostgrestException catch (error) {
      // Keep older installations usable until the holiday migration is run.
      if (error.code == '42P01' ||
          error.message.toLowerCase().contains('public_holidays')) {
        return <String>{};
      }
      rethrow;
    }
  }

  Future<int> countWorkingDays({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final DateTime normalizedStart = _dateOnly(
      startDate.isAfter(endDate) ? endDate : startDate,
    );
    final DateTime normalizedEnd = _dateOnly(
      startDate.isAfter(endDate) ? startDate : endDate,
    );
    final Set<String> holidays = await fetchPublicHolidayDates(
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );

    int count = 0;
    DateTime cursor = normalizedStart;
    while (!cursor.isAfter(normalizedEnd)) {
      if (isWorkingDay(cursor, holidays)) {
        count += 1;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static bool isWorkingDay(DateTime date, Set<String> publicHolidayDates) {
    final DateTime localDate = _dateOnly(date);
    final bool isWeekday =
        localDate.weekday >= DateTime.monday &&
        localDate.weekday <= DateTime.friday;
    return isWeekday && !publicHolidayDates.contains(_dateLabel(localDate));
  }

  static DateTime _dateOnly(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _dateLabel(DateTime value) {
    final DateTime date = _dateOnly(value);
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
