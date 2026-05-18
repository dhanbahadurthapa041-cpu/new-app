import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/student_service.dart';
import 'attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceRegisterSummary? todaySummary;
  List<AttendanceRegisterSummary> recentSummaries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final today = _dateOnly(DateTime.now());
    final savedStudents = await StorageService.loadAttendance(date: today);
    final summaries = await StorageService.loadRecentSummaries();

    if (!mounted) return;

    setState(() {
      todaySummary = savedStudents == null
          ? null
          : AttendanceRegisterSummary.fromStudents(today, savedStudents);
      recentSummaries = summaries;
      isLoading = false;
    });
  }

  Future<void> _openAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttendanceScreen()),
    );
    if (!mounted) return;
    await _loadDashboard();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final rosterCount = StudentService.getDummyStudents().length;
    final summary =
        todaySummary ??
        AttendanceRegisterSummary(
          date: _dateOnly(DateTime.now()),
          totalCount: rosterCount,
          onTimeCount: 0,
          lateCount: 0,
          absentCount: 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0D9488),
              foregroundColor: Colors.white,
              child: Icon(Icons.school, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Shree Bhawani Academy')),
          ],
        ),
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
          child: RefreshIndicator(
            onRefresh: _loadDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _HeroPanel(onStart: _openAttendance),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _AttendanceRatePanel(
                    summary: summary,
                    hasSavedAttendance: todaySummary != null,
                  ),
                  const SizedBox(height: 16),
                  _QuickMetrics(summary: summary),
                  const SizedBox(height: 16),
                  _RecentActivityPanel(summaries: recentSummaries),
                ],
              ],
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good day, Teacher',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Today\'s register is ready for Shree Bhawani Academy.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Start Today\'s Attendance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRatePanel extends StatelessWidget {
  const _AttendanceRatePanel({
    required this.summary,
    required this.hasSavedAttendance,
  });

  final AttendanceRegisterSummary summary;
  final bool hasSavedAttendance;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.presentRate * 100).round();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Attendance Rate',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasSavedAttendance
                          ? '${summary.presentCount} of ${summary.totalCount} students present'
                          : 'No attendance saved yet today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 76,
                width: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: summary.presentRate,
                        strokeWidth: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$percent%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.presentRate,
              minHeight: 10,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMetrics extends StatelessWidget {
  const _QuickMetrics({required this.summary});

  final AttendanceRegisterSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        icon: Icons.check_circle,
        label: 'On Time',
        value: summary.onTimeCount.toString(),
        color: Theme.of(context).colorScheme.primary,
      ),
      _MetricData(
        icon: Icons.schedule,
        label: 'Late',
        value: summary.lateCount.toString(),
        color: Theme.of(context).colorScheme.secondary,
      ),
      _MetricData(
        icon: Icons.cancel,
        label: 'Absent',
        value: summary.absentCount.toString(),
        color: Theme.of(context).colorScheme.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Metrics', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MetricTile(metric: metrics[0])),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(metric: metrics[1])),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(metric: metrics[2])),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.color, size: 24),
          const SizedBox(height: 12),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: metric.color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.summaries});

  final List<AttendanceRegisterSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (summaries.isEmpty)
            Text(
              'Saved attendance registers will appear here.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...summaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.event_available, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(summary.date),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary.presentCount} present, ${summary.lateCount} late, ${summary.absentCount} absent',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.72);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.72 : 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}
