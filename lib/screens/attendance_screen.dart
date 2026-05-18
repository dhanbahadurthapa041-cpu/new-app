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
  bool _hasUnsavedChanges = false;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    selectedDate = _dateOnly(selectedDate);
    _loadData();
  }

  Future<void> _loadData() async {
    final attendanceDate = selectedDate;

    setState(() {
      isLoading = true;
    });

    final savedStudents = await StorageService.loadAttendance(
      date: attendanceDate,
    );
    if (!mounted) return;

    setState(() {
      if (savedStudents != null && savedStudents.isNotEmpty) {
        students = savedStudents;
      } else {
        students = StudentService.getDummyStudents();
      }
      isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _submitAttendance() async {
    await StorageService.saveAttendance(students, date: selectedDate);
    if (!mounted) return;
    setState(() {
      _hasUnsavedChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance saved for ${_formatDate(selectedDate)}!'),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    if (_hasUnsavedChanges) {
      final shouldDiscard = await _confirmDiscardChanges();
      if (!shouldDiscard || !mounted) return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final nextDate = _dateOnly(pickedDate);
    if (nextDate == selectedDate) return;

    setState(() {
      selectedDate = nextDate;
    });
    await _loadData();
  }

  Future<bool> _confirmDiscardChanges() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'You have attendance changes that have not been submitted yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return shouldDiscard ?? false;
  }

  Future<void> _handleBlockedPop() async {
    final shouldDiscard = await _confirmDiscardChanges();
    if (!shouldDiscard || !mounted) return;

    setState(() {
      _hasUnsavedChanges = false;
    });
    Navigator.pop(context);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_hasUnsavedChanges) return;
        _handleBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_formatDate(selectedDate)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  AttendanceSummary(students: students),
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(student.rollNumber),
                            ),
                            title: Text(
                              student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Roll: ${student.rollNumber}'),
                                const SizedBox(height: 6),
                                RadioGroup<bool>(
                                  groupValue: student.isLate,
                                  onChanged: student.isPresent
                                      ? (value) {
                                          if (value == null) return;
                                          setState(() {
                                            student.isLate = value;
                                            _hasUnsavedChanges = true;
                                          });
                                        }
                                      : (_) {},
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      AttendanceRadioOption(
                                        label: 'On time',
                                        value: false,
                                        enabled: student.isPresent,
                                        onChanged: (value) {
                                          setState(() {
                                            student.isLate = value;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                      AttendanceRadioOption(
                                        label: 'Late',
                                        value: true,
                                        enabled: student.isPresent,
                                        onChanged: (value) {
                                          setState(() {
                                            student.isLate = value;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Switch(
                              value: student.isPresent,
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.5),
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              onChanged: (value) {
                                setState(() {
                                  student.isPresent = value;
                                  if (!value) {
                                    student.isLate = false;
                                  }
                                  _hasUnsavedChanges = true;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _submitAttendance,
          label: const Text('Submit Attendance'),
          icon: const Icon(Icons.send),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class AttendanceSummary extends StatelessWidget {
  const AttendanceSummary({required this.students, super.key});

  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    final onTimeCount = students
        .where((student) => student.isPresent && !student.isLate)
        .length;
    final lateCount = students
        .where((student) => student.isPresent && student.isLate)
        .length;
    final absentCount = students.where((student) => !student.isPresent).length;
    final totalCount = students.length;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SummaryBar(
              label: 'On time',
              count: onTimeCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            SummaryBar(
              label: 'Late',
              count: lateCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            SummaryBar(
              label: 'Absent',
              count: absentCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryBar extends StatelessWidget {
  const SummaryBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    super.key,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '$count/$total',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class AttendanceRadioOption extends StatelessWidget {
  const AttendanceRadioOption({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: enabled ? () => onChanged(value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: value,
            enabled: enabled,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
