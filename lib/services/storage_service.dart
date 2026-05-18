import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';
import 'student_service.dart';

class StorageService {
  static const String _attendanceKeyPrefix = 'attendance_data';
  static const String _legacyAttendanceKey = 'attendance_data';
  static const String _rosterKey = 'student_roster';

  static String attendanceKeyForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final month = normalizedDate.month.toString().padLeft(2, '0');
    final day = normalizedDate.day.toString().padLeft(2, '0');
    return '${_attendanceKeyPrefix}_${normalizedDate.year}-$month-$day';
  }

  static Future<List<Student>> loadMasterRoster() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_rosterKey);
    if (encodedData != null) {
      return _decodeStudents(encodedData);
    }
    // Fallback to dummy students if no roster saved yet
    final dummies = StudentService.getDummyStudents();
    await saveMasterRoster(dummies);
    return dummies;
  }

  static Future<void> saveMasterRoster(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      students.map((student) => student.toJson()).toList(),
    );
    await prefs.setString(_rosterKey, encodedData);
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

    final masterRoster = await loadMasterRoster();
    final masterIds = masterRoster.map((s) => s.id).toSet();

    if (encodedData != null) {
      final savedStudents = _decodeStudents(encodedData);
      // Filter out students who are no longer in the master roster
      return savedStudents.where((student) => masterIds.contains(student.id)).toList();
    }
    return null;
  }

  static Future<List<AttendanceRegisterSummary>> loadRecentSummaries({
    int limit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = <AttendanceRegisterSummary>[];
    final masterRoster = await loadMasterRoster();
    final masterIds = masterRoster.map((s) => s.id).toSet();

    for (final key in prefs.getKeys()) {
      final date = _dateFromAttendanceKey(key);
      if (date == null) continue;

      final encodedData = prefs.getString(key);
      if (encodedData == null) continue;

      final students = _decodeStudents(encodedData);
      // Filter out students who are no longer in the master roster
      final filteredStudents =
          students.where((student) => masterIds.contains(student.id)).toList();
      summaries.add(AttendanceRegisterSummary.fromStudents(date, filteredStudents));
    }

    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries.take(limit).toList();
  }

  static List<Student> _decodeStudents(String encodedData) {
    final List<dynamic> decodedData = jsonDecode(encodedData);
    return decodedData
        .map((item) => Student.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static DateTime? _dateFromAttendanceKey(String key) {
    final prefix = '${_attendanceKeyPrefix}_';
    if (!key.startsWith(prefix)) return null;

    final dateParts = key.substring(prefix.length).split('-');
    if (dateParts.length != 3) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime(year, month, day);
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class AttendanceRegisterSummary {
  const AttendanceRegisterSummary({
    required this.date,
    required this.totalCount,
    required this.onTimeCount,
    required this.lateCount,
    required this.absentCount,
  });

  factory AttendanceRegisterSummary.fromStudents(
    DateTime date,
    List<Student> students,
  ) {
    final onTimeCount = students
        .where((student) => student.isPresent && !student.isLate)
        .length;
    final lateCount = students
        .where((student) => student.isPresent && student.isLate)
        .length;
    final absentCount = students.where((student) => !student.isPresent).length;

    return AttendanceRegisterSummary(
      date: date,
      totalCount: students.length,
      onTimeCount: onTimeCount,
      lateCount: lateCount,
      absentCount: absentCount,
    );
  }

  final DateTime date;
  final int totalCount;
  final int onTimeCount;
  final int lateCount;
  final int absentCount;

  int get presentCount => onTimeCount + lateCount;

  double get presentRate {
    if (totalCount == 0) return 0;
    return presentCount / totalCount;
  }
}
