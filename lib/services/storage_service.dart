import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';

class StorageService {
  static const String _attendanceKey = 'attendance_data';

  // Save the list of students
  static Future<void> saveAttendance(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      students.map((student) => student.toJson()).toList(),
    );
    await prefs.setString(_attendanceKey, encodedData);
  }

  // Load the list of students
  static Future<List<Student>?> loadAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_attendanceKey);
    
    if (encodedData != null) {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData.map((item) => Student.fromJson(item as Map<String, dynamic>)).toList();
    }
    return null; // Return null if no data found
  }
}
