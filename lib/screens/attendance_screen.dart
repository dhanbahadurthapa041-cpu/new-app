import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';
import '../services/storage_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Student> students = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final savedStudents = await StorageService.loadAttendance();
    setState(() {
      if (savedStudents != null && savedStudents.isNotEmpty) {
        students = savedStudents;
      } else {
        students = StudentService.getDummyStudents();
      }
      isLoading = false;
    });
  }

  Future<void> _submitAttendance() async {
    await StorageService.saveAttendance(students);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved locally!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(student.rollNumber),
              ),
              title: Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Roll: ${student.rollNumber}'),
              trailing: Switch(
                value: student.isPresent,
                activeColor: Theme.of(context).colorScheme.secondary,
                onChanged: (value) {
                  setState(() {
                    student.isPresent = value;
                  });
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitAttendance,
        label: const Text('Submit Attendance'),
        icon: const Icon(Icons.send),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
