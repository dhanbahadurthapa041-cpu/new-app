import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';
import '../models/class_model.dart';

class StorageService {
  static const String _attendanceKeyPrefix = 'attendance';
  static const String _rosterKeyPrefix = 'roster';
  static const String _legacyRosterKey = 'student_roster';
  static const String _legacyAttendanceKey = 'attendance_data';
  static const String _classesListKey = 'classes_list';
  static const String _selectedClassIdKey = 'selected_class_id';
  static const String _schoolNameKey = 'school_name';

  static String attendanceKeyForDate(String classId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final month = normalizedDate.month.toString().padLeft(2, '0');
    final day = normalizedDate.day.toString().padLeft(2, '0');
    return '${_attendanceKeyPrefix}_${classId}_${normalizedDate.year}-$month-$day';
  }

  static String rosterKeyForClass(String classId) {
    return '${_rosterKeyPrefix}_$classId';
  }

  static Future<void> checkAndPerformMigration() async {
    final prefs = await SharedPreferences.getInstance();
    final classesJson = prefs.getString(_classesListKey);

    if (classesJson == null) {
      final legacyRosterJson = prefs.getString(_legacyRosterKey);

      if (legacyRosterJson != null) {
        final defaultClass = ClassModel(
          id: 'default_class',
          name: 'Default Class',
        );
        await prefs.setString(
          _classesListKey,
          jsonEncode([defaultClass.toJson()]),
        );
        await prefs.setString(_selectedClassIdKey, 'default_class');
        await prefs.setString(_schoolNameKey, 'My School');

        await prefs.setString(
          rosterKeyForClass('default_class'),
          legacyRosterJson,
        );

        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('${_legacyAttendanceKey}_')) {
            final dateStr = key.substring('${_legacyAttendanceKey}_'.length);
            final val = prefs.getString(key);
            if (val != null) {
              await prefs.setString('attendance_default_class_$dateStr', val);
            }
          }
        }
      }
    }
  }

  static Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    var classesJson = prefs.getString(_classesListKey);
    if (classesJson == null) {
      await checkAndPerformMigration();
      classesJson = prefs.getString(_classesListKey);
    }

    if (classesJson == null || classesJson == '[]' || classesJson.trim().isEmpty) {
      return false;
    }

    final schoolName = prefs.getString(_schoolNameKey);
    return schoolName != null && schoolName.trim().isNotEmpty;
  }

  static Future<String> loadSchoolName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_schoolNameKey) ?? '';
  }

  static Future<void> saveSchoolName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schoolNameKey, name.trim());
  }

  static Future<void> completeFirstRunSetup({
    required String schoolName,
    required String className,
    required List<Student> students,
  }) async {
    final newClass = ClassModel(
      id: 'class_${DateTime.now().millisecondsSinceEpoch}',
      name: className.trim(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schoolNameKey, schoolName.trim());
    await prefs.setString(_classesListKey, jsonEncode([newClass.toJson()]));
    await prefs.setString(_selectedClassIdKey, newClass.id);
    await prefs.setString(
      rosterKeyForClass(newClass.id),
      _encodeStudents(students),
    );
  }

  static Future<void> clearAllAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<List<ClassModel>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    var classesJson = prefs.getString(_classesListKey);
    if (classesJson == null) {
      await checkAndPerformMigration();
      classesJson = prefs.getString(_classesListKey);
    }

    if (classesJson != null) {
      try {
        final decoded = jsonDecode(classesJson);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(ClassModel.fromJson)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static int _getRosterCountFromPrefs(SharedPreferences prefs, String classId) {
    final String? encodedData = prefs.getString(rosterKeyForClass(classId));
    if (encodedData == null) return 0;
    try {
      final decodedData = jsonDecode(encodedData);
      if (decodedData is List) return decodedData.length;
    } catch (_) {}
    return 0;
  }

  static Future<Map<String, int>> getClassStudentCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await loadClasses();
    final counts = <String, int>{};
    for (final cls in classes) {
      counts[cls.id] = _getRosterCountFromPrefs(prefs, cls.id);
    }
    return counts;
  }

  static Future<void> saveClasses(List<ClassModel> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _classesListKey,
      jsonEncode(classes.map((c) => c.toJson()).toList()),
    );
  }

  static Future<String> getSelectedClassId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_selectedClassIdKey);
    if (id == null) {
      await checkAndPerformMigration();
      id = prefs.getString(_selectedClassIdKey) ?? '';
    }
    return id;
  }

  static Future<void> saveSelectedClassId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedClassIdKey, id);
  }

  static Future<ClassModel> createClass(String name) async {
    final classes = await loadClasses();
    final newClass = ClassModel(
      id: 'class_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    classes.add(newClass);
    await saveClasses(classes);
    return newClass;
  }

  static Future<void> deleteClass(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await loadClasses();
    classes.removeWhere((c) => c.id == classId);
    await saveClasses(classes);

    // Clean up roster
    await prefs.remove(rosterKeyForClass(classId));

    // Clean up attendance keys for this class
    final prefix = '${_attendanceKeyPrefix}_${classId}_';
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }

    // If deleted class was the selected class, reset selected class
    final currentSelected = prefs.getString(_selectedClassIdKey);
    if (currentSelected == classId) {
      if (classes.isNotEmpty) {
        await prefs.setString(_selectedClassIdKey, classes.first.id);
      } else {
        await prefs.remove(_selectedClassIdKey);
      }
    }
  }

  static Future<List<Student>> loadMasterRoster(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadMasterRosterFromPrefs(prefs, classId);
  }

  static Future<void> saveMasterRoster(
    String classId,
    List<Student> students,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      rosterKeyForClass(classId),
      _encodeStudents(students),
    );
  }

  static Future<void> saveAttendance(
    String classId,
    List<Student> students, {
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      attendanceKeyForDate(classId, date),
      _encodeStudents(students),
    );
  }

  static Future<List<Student>?> loadAttendance(
    String classId, {
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final masterRoster = await _loadMasterRosterFromPrefs(prefs, classId);
    return _loadAttendanceFromPrefs(
      prefs,
      classId,
      date: date,
      masterRoster: masterRoster,
    );
  }

  static Future<DashboardSnapshot> loadDashboardSnapshot(
    String classId, {
    DateTime? date,
    int recentLimit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardDate = _dateOnly(date ?? DateTime.now());
    final masterRoster = await _loadMasterRosterFromPrefs(prefs, classId);
    final savedStudents = _loadAttendanceFromPrefs(
      prefs,
      classId,
      date: dashboardDate,
      masterRoster: masterRoster,
    );
    final summaries = _loadRecentSummariesFromPrefs(
      prefs,
      classId,
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

  static Future<DashboardData> loadDashboardData({int recentLimit = 3}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load School Name
    final schoolName = prefs.getString(_schoolNameKey) ?? '';

    // 2. Load Classes
    final classesJson = prefs.getString(_classesListKey);
    final classes = <ClassModel>[];
    if (classesJson != null) {
      try {
        final decoded = jsonDecode(classesJson);
        if (decoded is List) {
          classes.addAll(decoded
              .whereType<Map<String, dynamic>>()
              .map(ClassModel.fromJson));
        }
      } catch (_) {}
    }

    // 3. Load Selected Class ID and Auto-Correct
    var selectedClassId = prefs.getString(_selectedClassIdKey) ?? '';
    if (classes.isNotEmpty) {
      final exists = classes.any((c) => c.id == selectedClassId);
      if (!exists) {
        selectedClassId = classes.first.id;
        await prefs.setString(_selectedClassIdKey, selectedClassId);
      }
    }

    // 4. Load Dashboard Snapshot
    DashboardSnapshot snapshot;
    if (selectedClassId.isNotEmpty) {
      final masterRoster = await _loadMasterRosterFromPrefs(prefs, selectedClassId);
      final dashboardDate = _dateOnly(DateTime.now());
      final savedStudents = _loadAttendanceFromPrefs(
        prefs,
        selectedClassId,
        date: dashboardDate,
        masterRoster: masterRoster,
      );
      final summaries = _loadRecentSummariesFromPrefs(
        prefs,
        selectedClassId,
        masterRoster: masterRoster,
        limit: recentLimit,
      );

      snapshot = DashboardSnapshot(
        rosterCount: masterRoster.length,
        todaySummary: savedStudents == null
            ? null
            : AttendanceRegisterSummary.fromStudents(
                dashboardDate,
                savedStudents,
              ),
        recentSummaries: summaries,
      );
    } else {
      snapshot = const DashboardSnapshot(
        rosterCount: 0,
        todaySummary: null,
        recentSummaries: [],
      );
    }

    return DashboardData(
      schoolName: schoolName,
      classes: classes,
      selectedClassId: selectedClassId,
      snapshot: snapshot,
    );
  }

  static List<Student>? _loadAttendanceFromPrefs(
    SharedPreferences prefs,
    String classId, {
    required DateTime date,
    required List<Student> masterRoster,
  }) {
    final String? encodedData =
        prefs.getString(attendanceKeyForDate(classId, date)) ??
        (_isToday(date) && classId == 'default_class'
            ? prefs.getString(_legacyAttendanceKey)
            : null);

    if (encodedData != null) {
      final savedStudents = _tryDecodeStudents(encodedData);
      if (savedStudents == null) return null;
      return _mergeAttendanceWithRoster(savedStudents, masterRoster);
    }
    return null;
  }

  static Future<List<AttendanceRegisterSummary>> loadRecentSummaries(
    String classId, {
    int limit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final masterRoster = await _loadMasterRosterFromPrefs(prefs, classId);
    return _loadRecentSummariesFromPrefs(
      prefs,
      classId,
      masterRoster: masterRoster,
      limit: limit,
    );
  }

  static List<AttendanceRegisterSummary> _loadRecentSummariesFromPrefs(
    SharedPreferences prefs,
    String classId, {
    required List<Student> masterRoster,
    required int limit,
  }) {
    final summaries = <AttendanceRegisterSummary>[];
    final masterIds = masterRoster.map((s) => s.id).toSet();

    // 1. Identify all keys that match the attendance pattern for this class, and parse dates
    final keyDatePairs = <MapEntry<String, DateTime>>[];
    for (final key in prefs.getKeys()) {
      final date = _dateFromAttendanceKey(key, classId);
      if (date != null) {
        keyDatePairs.add(MapEntry(key, date));
      }
    }

    // 2. Sort key-date pairs by date descending (most recent first)
    keyDatePairs.sort((a, b) => b.value.compareTo(a.value));

    // 3. Take the top `limit` pairs and only load/decode those
    final recentPairs = keyDatePairs.take(limit);

    for (final entry in recentPairs) {
      final key = entry.key;
      final date = entry.value;

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

    return summaries;
  }

  static Future<List<Student>> _loadMasterRosterFromPrefs(
    SharedPreferences prefs,
    String classId,
  ) async {
    final String? encodedData = prefs.getString(rosterKeyForClass(classId));
    final savedRoster = encodedData == null
        ? null
        : _tryDecodeStudents(encodedData);
    if (savedRoster != null) return savedRoster;

    return [];
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

  static DateTime? _dateFromAttendanceKey(String key, String classId) {
    final prefix = '${_attendanceKeyPrefix}_${classId}_';
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

class DashboardData {
  final String schoolName;
  final List<ClassModel> classes;
  final String selectedClassId;
  final DashboardSnapshot snapshot;

  const DashboardData({
    required this.schoolName,
    required this.classes,
    required this.selectedClassId,
    required this.snapshot,
  });
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
