import 'package:flutter/material.dart';

import '../models/student_model.dart';
import '../services/storage_service.dart';
import '../widgets/glass_panel.dart';
import '../utils/sorting_utils.dart';

class FirstRunSetupScreen extends StatefulWidget {
  const FirstRunSetupScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends State<FirstRunSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolController = TextEditingController();
  final _classController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _rollController = TextEditingController();
  final List<Student> _students = [];
  bool _isSaving = false;
  String? _selectedClass;

  static const List<String> _predefinedClasses = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
    'Custom Class...',
  ];

  @override
  void dispose() {
    _schoolController.dispose();
    _classController.dispose();
    _studentNameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _addStudent() {
    final name = _studentNameController.text.trim();
    final roll = _rollController.text.trim();
    if (name.isEmpty || roll.isEmpty) return;

    final rollExists = _students.any((student) => student.rollNumber == roll);
    if (rollExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That roll number is already in the list.'),
        ),
      );
      return;
    }

    setState(() {
      _students.add(
        Student(
          id: 'student_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          rollNumber: roll,
        ),
      );
      _students.sort((a, b) => compareRollNumbers(a.rollNumber, b.rollNumber));
      _studentNameController.clear();
      _rollController.clear();
    });
  }

  Future<void> _showImportDialog() async {
    final importController = TextEditingController();
    final imported = await showDialog<List<Student>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Students'),
          content: TextField(
            controller: importController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '101, Aarav Sharma\n102, Bipasha Thapa',
              helperText: 'Use one student per line: roll number, name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _parseImportedStudents(importController.text),
                );
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    importController.dispose();

    if (imported == null || imported.isEmpty) return;
    setState(() {
      final existingRolls = _students
          .map((student) => student.rollNumber)
          .toSet();
      for (final student in imported) {
        if (!existingRolls.contains(student.rollNumber)) {
          _students.add(student);
          existingRolls.add(student.rollNumber);
        }
      }
      _students.sort((a, b) => compareRollNumbers(a.rollNumber, b.rollNumber));
    });
  }

  List<Student> _parseImportedStudents(String text) {
    final students = <Student>[];
    final seenRolls = <String>{};
    final lines = text.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 2) continue;

      final roll = parts.first.trim();
      final name = parts.sublist(1).join(',').trim();
      if (roll.isEmpty || name.isEmpty || seenRolls.contains(roll)) continue;

      seenRolls.add(roll);
      students.add(
        Student(
          id: 'student_${DateTime.now().microsecondsSinceEpoch}_${students.length}',
          name: name,
          rollNumber: roll,
        ),
      );
    }

    return students;
  }

  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final currentName = _studentNameController.text.trim();
    final currentRoll = _rollController.text.trim();
    if (currentName.isNotEmpty && currentRoll.isNotEmpty) {
      final rollExists = _students.any((student) => student.rollNumber == currentRoll);
      if (!rollExists) {
        _students.add(
          Student(
            id: 'student_${DateTime.now().microsecondsSinceEpoch}',
            name: currentName,
            rollNumber: currentRoll,
          ),
        );
      }
    }

    setState(() {
      _isSaving = true;
    });

    final finalClassName = _selectedClass == 'Custom Class...'
        ? _classController.text.trim()
        : (_selectedClass ?? '');

    await StorageService.completeFirstRunSetup(
      schoolName: _schoolController.text,
      className: finalClassName,
      students: _students,
    );

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  Text(
                    'Set Up Attendance',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your school, first class, and students to start with real data.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _schoolController,
                            decoration: const InputDecoration(
                              labelText: 'School Name',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a school name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedClass,
                            decoration: const InputDecoration(
                              labelText: 'First Class',
                              prefixIcon: Icon(Icons.class_outlined),
                            ),
                            items: _predefinedClasses.map((cls) {
                              return DropdownMenuItem<String>(
                                value: cls,
                                child: Text(cls),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClass = val;
                              });
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please select a class';
                              }
                              return null;
                            },
                          ),
                          if (_selectedClass == 'Custom Class...') ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _classController,
                              decoration: const InputDecoration(
                                labelText: 'Custom Class Name',
                                hintText: 'e.g. Grade 8, Class 3B',
                                prefixIcon: Icon(Icons.edit_note),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter a custom class name';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Students',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showImportDialog,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Import'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _studentNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _rollController,
                                decoration: const InputDecoration(
                                  labelText: 'Roll',
                                  prefixIcon: Icon(Icons.numbers),
                                ),
                                keyboardType: TextInputType.number,
                                onSubmitted: (_) => _addStudent(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addStudent,
                              icon: const Icon(Icons.add),
                              tooltip: 'Add Student',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_students.isEmpty)
                          Text(
                            'You can start with an empty roster and add students later.',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          ..._students.map(
                            (student) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(student.rollNumber),
                              ),
                              title: Text(student.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove Student',
                                onPressed: () {
                                  setState(() {
                                    _students.remove(student);
                                  });
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _finishSetup,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Finish Setup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF0B1120)]
        : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)];
  }
}
