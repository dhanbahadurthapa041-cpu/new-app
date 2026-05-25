import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/class_model.dart';
import '../services/storage_service.dart';
import '../widgets/glass_panel.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _schoolController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _remindersEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  List<ClassModel> _classes = [];
  String? _exportClassId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final schoolName = await StorageService.loadSchoolName();
    final classes = await StorageService.loadClasses();
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool('reminders_enabled') ?? false;
    final hour = prefs.getInt('reminder_hour') ?? 9;
    final minute = prefs.getInt('reminder_minute') ?? 0;

    if (!mounted) return;
    setState(() {
      _schoolController.text = schoolName;
      _classes = classes;
      if (_classes.isNotEmpty) {
        _exportClassId = _classes.first.id;
      } else {
        _exportClassId = null;
      }
      _remindersEnabled = remindersEnabled;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _isLoading = false;
    });
  }

  Future<void> _saveSchoolName() async {
    final name = _schoolController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School name cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    await StorageService.saveSchoolName(name);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('School name updated.')));
  }

  Future<void> _toggleReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', value);

    setState(() {
      _remindersEnabled = value;
    });

    if (value) {
      final granted = await NotificationService.requestPermissions();
      if (granted) {
        await NotificationService.scheduleDailyReminder(_reminderTime.hour, _reminderTime.minute);
      } else {
        await prefs.setBool('reminders_enabled', false);
        setState(() {
          _remindersEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permissions are required for reminders.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      await NotificationService.cancelAllReminders();
    }
  }

  Future<void> _exportClassToJson() async {
    if (_exportClassId == null) return;
    final classId = _exportClassId!;
    final cls = _classes.firstWhere((c) => c.id == classId);
    final className = cls.name;

    try {
      final jsonString = await StorageService.exportClassToJson(classId);
      final String safeName = className.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${safeName}_roster_attendance.json';

      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Class Data (JSON)',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path == null) return; // cancelled

      final file = File(path);
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class data exported successfully to $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportClassToCsv() async {
    if (_exportClassId == null) return;
    final classId = _exportClassId!;
    final cls = _classes.firstWhere((c) => c.id == classId);
    final className = cls.name;

    try {
      final csvString = await StorageService.exportClassToCsv(classId);
      final String safeName = className.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${safeName}_attendance_report.csv';

      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Attendance Report (CSV)',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (path == null) return; // cancelled

      final file = File(path);
      await file.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV report exported successfully to $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importClass() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      await StorageService.importClassFromJson(content);

      // Reload classes
      final classes = await StorageService.loadClasses();

      if (mounted) {
        setState(() {
          _classes = classes;
          if (_classes.isNotEmpty) {
            _exportClassId = _classes.first.id;
          } else {
            _exportClassId = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class data imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed. Make sure it is a valid exported class JSON file.\nError: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );

    if (pickedTime != null && pickedTime != _reminderTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_hour', pickedTime.hour);
      await prefs.setInt('reminder_minute', pickedTime.minute);

      setState(() {
        _reminderTime = pickedTime;
      });

      if (_remindersEnabled) {
        await NotificationService.scheduleDailyReminder(pickedTime.hour, pickedTime.minute);
      }
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This removes the school setup, classes, rosters, and saved attendance from this device. This action cannot be undone.',
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
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await StorageService.clearAllAppData();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Profile',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schoolController,
                            decoration: const InputDecoration(
                              labelText: 'School Name',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _saveSchoolName,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save Name'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminders',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Daily Attendance Reminder'),
                            subtitle: const Text('Get notified daily to take attendance'),
                            value: _remindersEnabled,
                            onChanged: _toggleReminders,
                          ),
                          if (_remindersEnabled) ...[
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Reminder Time'),
                              subtitle: Text(_reminderTime.format(context)),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.primary),
                              onTap: _selectTime,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data Sharing',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Export your classes to share them with other teachers or import class JSON files.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Divider(height: 24),
                          Text(
                            'Import Class',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _importClass,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Import Class (.json)'),
                          ),
                          const Divider(height: 32),
                          Text(
                            'Export Class',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (_classes.isEmpty)
                            Text(
                              'No classes available to export.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: _exportClassId,
                              decoration: const InputDecoration(
                                labelText: 'Class to Export',
                                prefixIcon: Icon(Icons.class_outlined),
                              ),
                              items: _classes.map((cls) {
                                return DropdownMenuItem<String>(
                                  value: cls.id,
                                  child: Text(cls.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _exportClassId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _exportClassToJson,
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('Share (.json)'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _exportClassToCsv,
                                    icon: const Icon(Icons.table_view_outlined),
                                    label: const Text('Excel (.csv)'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clear local data when you want to set up the app again from a blank state.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _clearData,
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Clear All Data'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
