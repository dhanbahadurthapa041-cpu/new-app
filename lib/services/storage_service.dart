import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';

class StorageService {
  static const String _attendanceKeyPrefix = 'attendance_data';
  static const String _legacyAttendanceKey = 'attendance_data';

  static String attendanceKeyForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final month = normalizedDate.month.toString().padLeft(2, '0');
    final day = normalizedDate.day.toString().padLeft(2, '0');
    return '${_attendanceKeyPrefix}_${normalizedDate.year}-$month-$day';
  }

  static Future<void> saveAttendance(
    List<Student> students, {
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      students.map((student) => student.toJson()).toList(),
    );
    await prefs.setString(attendanceKeyForDate(date), encodedData);
  }

  static Future<List<Student>?> loadAttendance({required DateTime date}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData =
        prefs.getString(attendanceKeyForDate(date)) ??
        (_isToday(date) ? prefs.getString(_legacyAttendanceKey) : null);

    if (encodedData != null) {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData
          .map((item) => Student.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
