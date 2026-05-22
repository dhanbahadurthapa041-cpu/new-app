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
    return _loadMasterRosterFromPrefs(prefs);
  }

  static Future<void> saveMasterRoster(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rosterKey, _encodeStudents(students));
  }

  static Future<void> saveAttendance(
    List<Student> students, {
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      attendanceKeyForDate(date),
      _encodeStudents(students),
    );
  }

  static Future<List<Student>?> loadAttendance({required DateTime date}) async {
    final prefs = await SharedPreferences.getInstance();
    final masterRoster = await _loadMasterRosterFromPrefs(prefs);
    return _loadAttendanceFromPrefs(
      prefs,
      date: date,
      masterRoster: masterRoster,
    );
  }

  static Future<DashboardSnapshot> loadDashboardSnapshot({
    DateTime? date,
    int recentLimit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardDate = _dateOnly(date ?? DateTime.now());
    final masterRoster = await _loadMasterRosterFromPrefs(prefs);
    final savedStudents = _loadAttendanceFromPrefs(
      prefs,
      date: dashboardDate,
      masterRoster: masterRoster,
    );
    final summaries = _loadRecentSummariesFromPrefs(
      prefs,
      masterRoster: masterRoster,
      limit: recentLimit,
    );

    return DashboardSnapshot(
      rosterCount: masterRoster.length,
      todaySummary: savedStudents == null
          ? null
          : AttendanceRegisterSummary.fromStudents(
              dashboardDate,
              savedStudents,
            ),
      recentSummaries: summaries,
    );
  }

  static List<Student>? _loadAttendanceFromPrefs(
    SharedPreferences prefs, {
    required DateTime date,
    required List<Student> masterRoster,
  }) {
    final String? encodedData =
        prefs.getString(attendanceKeyForDate(date)) ??
        (_isToday(date) ? prefs.getString(_legacyAttendanceKey) : null);

    if (encodedData != null) {
      final savedStudents = _tryDecodeStudents(encodedData);
      if (savedStudents == null) return null;
      return _mergeAttendanceWithRoster(savedStudents, masterRoster);
    }
    return null;
  }

  static Future<List<AttendanceRegisterSummary>> loadRecentSummaries({
    int limit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final masterRoster = await _loadMasterRosterFromPrefs(prefs);
    return _loadRecentSummariesFromPrefs(
      prefs,
      masterRoster: masterRoster,
      limit: limit,
    );
  }

  static List<AttendanceRegisterSummary> _loadRecentSummariesFromPrefs(
    SharedPreferences prefs, {
    required List<Student> masterRoster,
    required int limit,
  }) {
    final summaries = <AttendanceRegisterSummary>[];
    final masterIds = masterRoster.map((s) => s.id).toSet();

    for (final key in prefs.getKeys()) {
      final date = _dateFromAttendanceKey(key);
      if (date == null) continue;

      final encodedData = prefs.getString(key);
      if (encodedData == null) continue;

      final students = _tryDecodeStudents(encodedData);
      if (students == null) continue;

      final filteredStudents = students
          .where((student) => masterIds.contains(student.id))
          .toList();
      summaries.add(
        AttendanceRegisterSummary.fromStudents(date, filteredStudents),
      );
    }

    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries.take(limit).toList();
  }

  static Future<List<Student>> _loadMasterRosterFromPrefs(
    SharedPreferences prefs,
  ) async {
    final String? encodedData = prefs.getString(_rosterKey);
    final savedRoster = encodedData == null
        ? null
        : _tryDecodeStudents(encodedData);
    if (savedRoster != null) return savedRoster;

    final defaultRoster = StudentService.getDummyStudents();
    await prefs.setString(_rosterKey, _encodeStudents(defaultRoster));
    return defaultRoster;
  }

  static List<Student> _mergeAttendanceWithRoster(
    List<Student> savedStudents,
    List<Student> masterRoster,
  ) {
    final savedById = {
      for (final student in savedStudents) student.id: student,
    };
    return masterRoster.map((rosterStudent) {
      final savedStudent = savedById[rosterStudent.id];
      return Student(
        id: rosterStudent.id,
        name: rosterStudent.name,
        rollNumber: rosterStudent.rollNumber,
        isPresent: savedStudent?.isPresent ?? true,
        isLate: savedStudent?.isLate ?? false,
      );
    }).toList();
  }

  static String _encodeStudents(List<Student> students) {
    return jsonEncode(students.map((student) => student.toJson()).toList());
  }

  static List<Student>? _tryDecodeStudents(String encodedData) {
    try {
      final decodedData = jsonDecode(encodedData);
      if (decodedData is! List) return null;

      return decodedData
          .whereType<Map<String, dynamic>>()
          .map(Student.fromJson)
          .toList();
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
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

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.rosterCount,
    required this.todaySummary,
    required this.recentSummaries,
  });

  final int rosterCount;
  final AttendanceRegisterSummary? todaySummary;
  final List<AttendanceRegisterSummary> recentSummaries;
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
