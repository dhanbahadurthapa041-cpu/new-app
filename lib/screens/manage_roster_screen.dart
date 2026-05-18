import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart'; // For GlassPanel or custom components if any, or we can write custom ones.

class ManageRosterScreen extends StatefulWidget {
  const ManageRosterScreen({super.key});

  @override
  State<ManageRosterScreen> createState() => _ManageRosterScreenState();
}

class _ManageRosterScreenState extends State<ManageRosterScreen> {
  List<Student> roster = [];
  bool isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      isLoading = true;
    });
    final loadedRoster = await StorageService.loadMasterRoster();
    if (!mounted) return;
    setState(() {
      roster = loadedRoster;
      // Sort by roll number for a neat structural listing
      roster.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      isLoading = false;
    });
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final newStudent = Student(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      rollNumber: _rollController.text.trim(),
    );

    setState(() {
      roster.add(newStudent);
      roster.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    });

    await StorageService.saveMasterRoster(roster);

    _nameController.clear();
    _rollController.clear();

    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newStudent.name} added to the roster!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _removeStudent(Student student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text(
          'Are you sure you want to remove ${student.name} (Roll: ${student.rollNumber}) from the roster?\n\nThis will filter them out of daily records but won\'t modify historical submissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      roster.removeWhere((s) => s.id == student.id);
    });

    await StorageService.saveMasterRoster(roster);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${student.name} removed from roster.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.person_add,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Text('Add Student'),
            ],
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter student\'s full name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rollController,
                  decoration: const InputDecoration(
                    labelText: 'Roll Number',
                    hintText: 'Enter roll number',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a roll number';
                    }
                    final rollExists = roster.any(
                      (student) => student.rollNumber == value.trim(),
                    );
                    if (rollExists) {
                      return 'This roll number already exists';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                _rollController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _addStudent,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  List<Color> _backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF0B1120)]
        : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage School Roster'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : roster.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.24),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Students in Roster',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the "+" button below to add your first child.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: roster.length,
                      itemBuilder: (context, index) {
                        final student = roster[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassPanel(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    student.rollNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Roll Number: ${student.rollNumber}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: () => _removeStudent(student),
                                  tooltip: 'Remove Student',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }
}
