import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../services/storage_service.dart';
import '../widgets/glass_panel.dart';
import 'attendance_screen.dart';
import 'manage_roster_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onSetupRequired, super.key});

  final VoidCallback onSetupRequired;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceRegisterSummary? todaySummary;
  List<AttendanceRegisterSummary> recentSummaries = [];
  bool isLoading = true;
  int _rosterCount = 0;
  String schoolName = '';
  List<ClassModel> classes = [];
  ClassModel? selectedClass;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }

    final data = await StorageService.loadDashboardData();

    if (!mounted) return;

    setState(() {
      schoolName = data.schoolName;
      classes = data.classes;
      _rosterCount = data.snapshot.rosterCount;
      todaySummary = data.snapshot.todaySummary;
      recentSummaries = data.snapshot.recentSummaries;

      if (classes.isNotEmpty) {
        selectedClass = classes.firstWhere(
          (c) => c.id == data.selectedClassId,
          orElse: () => classes.first,
        );
      } else {
        selectedClass = null;
      }

      isLoading = false;
    });
  }

  Future<void> _openAttendance({DateTime? date}) async {
    if (selectedClass == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AttendanceScreen(classId: selectedClass!.id, initialDate: date),
      ),
    );
    if (!mounted) return;
    await _loadDashboard();
  }

  Future<void> _openSettings() async {
    final shouldReturnToSetup = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (!mounted) return;
    if (shouldReturnToSetup == true) {
      widget.onSetupRequired();
      return;
    }
    await _loadDashboard();
  }

  Future<void> _createNewClass() async {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Class'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'e.g. Grade 8, Class 3B',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a name';
              }
              final nameExists = classes.any(
                (c) => c.name.toLowerCase() == val.trim().toLowerCase(),
              );
              if (nameExists) {
                return 'A class with this name already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, textController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    final newClass = await StorageService.createClass(name);
    await StorageService.saveSelectedClassId(newClass.id);
    await _loadDashboard();
  }

  Future<void> _deleteClass(ClassModel classModel) async {
    if (classes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last remaining class.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class?'),
        content: Text(
          'Are you sure you want to delete "${classModel.name}"?\n\nThis will permanently delete the roster and all historical attendance registers for this class. This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });

    await StorageService.deleteClass(classModel.id);
    await _loadDashboard();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Class "${classModel.name}" deleted.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showClassSelectionBottomSheet() async {
    final counts = await StorageService.getClassStudentCounts();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Class',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Add Class',
                        onPressed: () async {
                          Navigator.pop(context);
                          await _createNewClass();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final cls = classes[index];
                        final isSelected = cls.id == selectedClass?.id;
                        final count = counts[cls.id] ?? 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.12)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                            foregroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            child: const Icon(Icons.class_outlined),
                          ),
                          title: Text(
                            cls.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('$count students'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              if (classes.length > 1) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _deleteClass(cls);
                                  },
                                ),
                              ],
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            if (!isSelected) {
                              setState(() {
                                isLoading = true;
                              });
                              await StorageService.saveSelectedClassId(cls.id);
                              await _loadDashboard();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        todaySummary ??
        AttendanceRegisterSummary(
          date: _dateOnly(DateTime.now()),
          totalCount: _rosterCount,
          onTimeCount: 0,
          lateCount: 0,
          absentCount: 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showClassSelectionBottomSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schoolName.isEmpty ? 'Attendance' : schoolName,
                style: const TextStyle(fontSize: 16),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedClass?.name ?? 'Select Class',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Roster',
            onPressed: () async {
              if (selectedClass == null) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ManageRosterScreen(classId: selectedClass!.id),
                ),
              );
              _loadDashboard();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
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
              ? const _DashboardLoadingView()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      _HeroPanel(
                        schoolName: schoolName,
                        onStart: () => _openAttendance(),
                      ),
                      const SizedBox(height: 16),
                      _AttendanceRatePanel(
                        summary: summary,
                        hasSavedAttendance: todaySummary != null,
                      ),
                      const SizedBox(height: 16),
                      _QuickMetrics(summary: summary),
                      const SizedBox(height: 16),
                      _RecentActivityPanel(
                        summaries: recentSummaries,
                        onTapItem: (date) => _openAttendance(date: date),
                      ),
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

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              width: 52,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Preparing dashboard',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Loading roster and recent attendance',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.schoolName, required this.onStart});

  final String schoolName;
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
            'Ready for Attendance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Today\'s register is ready for ${schoolName.isEmpty ? 'your school' : schoolName}.',
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
        SizedBox(
          height: 112,
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
  const _RecentActivityPanel({
    required this.summaries,
    required this.onTapItem,
  });

  final List<AttendanceRegisterSummary> summaries;
  final ValueChanged<DateTime> onTapItem;

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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapItem(summary.date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
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
