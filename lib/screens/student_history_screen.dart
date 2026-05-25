import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/storage_service.dart';

class StudentHistoryScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName;
  final String rollNumber;

  const StudentHistoryScreen({
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    super.key,
  });

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  bool _isLoading = true;
  int _presentCount = 0;
  int _lateCount = 0;
  int _absentCount = 0;
  int _activeDays = 0;
  double _attendanceRate = 0.0;
  int _currentStreak = 0;

  // Chronological attendance log
  List<MapEntry<DateTime, Student>> _attendanceLog = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await StorageService.loadAllAttendanceRecords(widget.classId);
      final sortedDatesAscending = records.keys.toList()..sort();
      final sortedDatesDescending = records.keys.toList()..sort((a, b) => b.compareTo(a));

      int present = 0;
      int late = 0;
      int absent = 0;
      int activeDays = 0;
      final log = <MapEntry<DateTime, Student>>[];

      // 1. Calculate general stats & build log
      for (final date in sortedDatesAscending) {
        final dayStudents = records[date] ?? [];
        final sRecord = dayStudents.firstWhere(
          (s) => s.id == widget.studentId,
          orElse: () => Student(id: '', name: '', rollNumber: ''),
        );

        if (sRecord.id.isNotEmpty) {
          activeDays++;
          if (sRecord.isPresent) {
            present++;
            if (sRecord.isLate) {
              late++;
            }
          } else {
            absent++;
          }
          log.add(MapEntry(date, sRecord));
        }
      }

      // Reverse log for UI listing (most recent first)
      final chronologicalLog = log.reversed.toList();

      // 2. Calculate current present streak from descending sorted dates
      int streak = 0;
      for (final date in sortedDatesDescending) {
        final dayStudents = records[date] ?? [];
        final sRecord = dayStudents.firstWhere(
          (s) => s.id == widget.studentId,
          orElse: () => Student(id: '', name: '', rollNumber: ''),
        );

        if (sRecord.id.isNotEmpty) {
          if (sRecord.isPresent) {
            streak++;
          } else {
            break; // Streak broken by absence
          }
        }
      }

      final rate = activeDays > 0 ? (present / activeDays) : 0.0;

      if (mounted) {
        setState(() {
          _presentCount = present;
          _lateCount = late;
          _absentCount = absent;
          _activeDays = activeDays;
          _attendanceRate = rate;
          _currentStreak = streak;
          _attendanceLog = chronologicalLog;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratePct = (_attendanceRate * 100).round();

    Color rateColor = theme.colorScheme.primary;
    if (_attendanceRate < 0.75) {
      rateColor = theme.colorScheme.error;
    } else if (ratePct >= 90) {
      rateColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                // Student card
                Card(
                  elevation: 0,
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: rateColor.withValues(alpha: 0.1),
                          foregroundColor: rateColor,
                          child: Text(
                            widget.rollNumber,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.studentName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Roll Number: ${widget.rollNumber}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Attendance Rate indicator
                Card(
                  elevation: 0,
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Attendance',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _activeDays > 0
                                    ? 'Present in $_presentCount out of $_activeDays active class days'
                                    : 'No attendance records registered yet',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _attendanceRate,
                                strokeWidth: 5,
                                backgroundColor: rateColor.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                              ),
                              Text(
                                '$ratePct%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: rateColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Streak Card
                if (_currentStreak > 0)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Presence Streak',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Present for $_currentStreak consecutive active class days!',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_currentStreak > 0) const SizedBox(height: 16),

                // Stats breakdown Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _buildStatCard('Present', _presentCount.toString(), Colors.green, Icons.check_circle_outline),
                    _buildStatCard('Late', _lateCount.toString(), theme.colorScheme.secondary, Icons.schedule),
                    _buildStatCard('Absent', _absentCount.toString(), theme.colorScheme.error, Icons.cancel_outlined),
                    _buildStatCard('Class Days', _activeDays.toString(), theme.colorScheme.primary, Icons.calendar_today_outlined),
                  ],
                ),
                const SizedBox(height: 20),

                // Attendance log timeline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'Attendance Log',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                if (_attendanceLog.isEmpty)
                  Card(
                    elevation: 0,
                    color: isDark ? theme.colorScheme.surface : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No logs found for this student',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    color: isDark ? theme.colorScheme.surface : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attendanceLog.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final entry = _attendanceLog[index];
                        final date = entry.key;
                        final record = entry.value;

                        String statusLabel = 'Present';
                        Color statusColor = Colors.green;
                        if (!record.isPresent) {
                          statusLabel = 'Absent';
                          statusColor = theme.colorScheme.error;
                        } else if (record.isLate) {
                          statusLabel = 'Late';
                          statusColor = theme.colorScheme.secondary;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            _formatDate(date),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
