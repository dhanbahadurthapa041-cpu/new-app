import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/storage_service.dart';
import 'student_history_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AnalyticsScreen({
    required this.classId,
    required this.className,
    super.key,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Historical data structures
  Map<DateTime, List<Student>> _records = {};
  List<DateTime> _sortedDates = [];
  
  // Computed statistics
  double _classAverageRate = 0.0;
  DateTime? _bestDay;
  double _bestDayRate = 0.0;
  DateTime? _worstDay;
  double _worstDayRate = 1.0;
  
  List<MapEntry<String, double>> _monthlyAverages = []; // e.g., ["May 2026", 0.92]
  List<MapEntry<DateTime, double>> _weeklyTrend = []; // last 7 sessions
  List<StudentStats> _studentStatsList = [];
  List<StudentStats> _filteredStudentStatsList = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnalytics();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await StorageService.loadAllAttendanceRecords(widget.classId);
      final masterRoster = await StorageService.loadMasterRoster(widget.classId);
      
      if (records.isEmpty) {
        if (mounted) {
          setState(() {
            _records = {};
            _isLoading = false;
          });
        }
        return;
      }

      final sortedDates = records.keys.toList()..sort();
      
      // Calculate class overall average
      double totalRatesSum = 0.0;
      DateTime? bestDay;
      double maxRate = -1.0;
      DateTime? worstDay;
      double minRate = 2.0;

      for (final date in sortedDates) {
        final students = records[date] ?? [];
        if (students.isEmpty) continue;
        
        final presentCount = students.where((s) => s.isPresent).length;
        final dayRate = presentCount / students.length;
        
        totalRatesSum += dayRate;

        if (dayRate > maxRate) {
          maxRate = dayRate;
          bestDay = date;
        }
        if (dayRate < minRate) {
          minRate = dayRate;
          worstDay = date;
        }
      }

      final classAverageRate = sortedDates.isNotEmpty ? (totalRatesSum / sortedDates.length) : 0.0;

      // Group by Month
      final monthlySum = <String, List<double>>{};
      final monthFormat = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      for (final date in sortedDates) {
        final key = '${monthFormat[date.month - 1]} ${date.year}';
        final students = records[date] ?? [];
        if (students.isEmpty) continue;
        final dayRate = students.where((s) => s.isPresent).length / students.length;
        
        monthlySum.putIfAbsent(key, () => []).add(dayRate);
      }

      final monthlyAverages = monthlySum.entries.map((entry) {
        final rates = entry.value;
        final avg = rates.reduce((a, b) => a + b) / rates.length;
        return MapEntry(entry.key, avg);
      }).toList();

      // Weekly trend (last 7 sessions)
      final trendCount = sortedDates.length > 7 ? 7 : sortedDates.length;
      final weeklyTrend = sortedDates
          .sublist(sortedDates.length - trendCount)
          .map((date) {
            final students = records[date] ?? [];
            final rate = students.isEmpty
                ? 0.0
                : students.where((s) => s.isPresent).length / students.length;
            return MapEntry(date, rate);
          })
          .toList();

      // Calculate individual student statistics
      final studentStatsList = <StudentStats>[];
      for (final student in masterRoster) {
        int present = 0;
        int late = 0;
        int absent = 0;
        int activeDays = 0;

        for (final date in sortedDates) {
          final dayStudents = records[date] ?? [];
          final record = dayStudents.firstWhere(
            (s) => s.id == student.id,
            orElse: () => Student(id: '', name: '', rollNumber: ''),
          );

          if (record.id.isNotEmpty) {
            activeDays++;
            if (record.isPresent) {
              present++;
              if (record.isLate) {
                late++;
              }
            } else {
              absent++;
            }
          }
        }

        final rate = activeDays > 0 ? (present / activeDays) : 0.0;
        studentStatsList.add(
          StudentStats(
            student: student,
            presentCount: present,
            lateCount: late,
            absentCount: absent,
            activeDays: activeDays,
            attendanceRate: rate,
          ),
        );
      }

      // Sort students by attendance rate descending
      studentStatsList.sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));

      if (mounted) {
        setState(() {
          _records = records;
          _sortedDates = sortedDates;
          _classAverageRate = classAverageRate;
          _bestDay = bestDay;
          _bestDayRate = maxRate;
          _worstDay = worstDay;
          _worstDayRate = minRate;
          _monthlyAverages = monthlyAverages;
          _weeklyTrend = weeklyTrend;
          _studentStatsList = studentStatsList;
          _filteredStudentStatsList = List.from(studentStatsList);
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStudentStatsList = List.from(_studentStatsList);
      } else {
        _filteredStudentStatsList = _studentStatsList.where((stat) {
          return stat.student.name.toLowerCase().contains(query) ||
              stat.student.rollNumber.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reports & Analytics'),
            Text(
              widget.className,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview & Trends', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Student Breakdown', icon: Icon(Icons.people_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildStudentBreakdownTab(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.24),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data to Analyze',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Save attendance for this class first, then come here to view weekly/monthly reports and student rankings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Cards Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              title: 'Avg Attendance',
              value: '${(_classAverageRate * 100).round()}%',
              icon: Icons.pie_chart_outline_outlined,
              color: theme.colorScheme.primary,
            ),
            _buildStatCard(
              title: 'Total Active Days',
              value: _sortedDates.length.toString(),
              icon: Icons.calendar_today_outlined,
              color: theme.colorScheme.secondary,
            ),
            if (_bestDay != null)
              _buildStatCard(
                title: 'Best Session',
                value: '${(_bestDayRate * 100).round()}%',
                subtitle: _formatDate(_bestDay!),
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            if (_worstDay != null)
              _buildStatCard(
                title: 'Worst Session',
                value: '${(_worstDayRate * 100).round()}%',
                subtitle: _formatDate(_worstDay!),
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom painter Line Chart for Weekly Trend
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Trend (Last 7 Sessions)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      dataPoints: _weeklyTrend,
                      theme: theme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Monthly average bar chart
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_monthlyAverages.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(child: Text('No monthly data')),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _monthlyAverages.map((entry) {
                      return _buildBarColumn(entry.key, entry.value);
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
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
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarColumn(String month, double rate) {
    final theme = Theme.of(context);
    final percent = (rate * 100).round();
    const maxHeight = 120.0;
    final barHeight = rate * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$percent%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: barHeight < 6 ? 6 : barHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          month,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStudentBreakdownTab() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search student by name or roll...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.16)),
              ),
            ),
          ),
        ),
        
        // List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Standings',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Attendance Rate',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List View
        Expanded(
          child: _filteredStudentStatsList.isEmpty
              ? Center(
                  child: Text(
                    'No students found matching query',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredStudentStatsList.length,
                  itemBuilder: (context, index) {
                    final stats = _filteredStudentStatsList[index];
                    final ratePct = (stats.attendanceRate * 100).round();
                    
                    // Danger/alert if below 75%
                    final isLowAttendance = stats.attendanceRate < 0.75;
                    final rateColor = isLowAttendance
                        ? theme.colorScheme.error
                        : ratePct >= 90
                            ? Colors.green
                            : theme.colorScheme.primary;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: rateColor.withValues(alpha: 0.1),
                            foregroundColor: rateColor,
                            child: Text(
                              stats.student.rollNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            stats.student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Presents: ${stats.presentCount} | Lates: ${stats.lateCount} | Absents: ${stats.absentCount}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rateColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$ratePct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rateColor,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentHistoryScreen(
                                  classId: widget.classId,
                                  studentId: stats.student.id,
                                  studentName: stats.student.name,
                                  rollNumber: stats.student.rollNumber,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 80, endIndent: 24),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class StudentStats {
  final Student student;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int activeDays;
  final double attendanceRate;

  StudentStats({
    required this.student,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.activeDays,
    required this.attendanceRate,
  });
}

// Custom Painter to draw a clean, simple line chart for the last 7 sessions
class LineChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> dataPoints;
  final ThemeData theme;

  LineChartPainter({required this.dataPoints, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paintLine = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..style = PaintingStyle.fill;

    final paintDot = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = theme.colorScheme.onSurface.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;
    
    // Y padding (top for labels, bottom for dates)
    const double topPadding = 12.0;
    const double bottomPadding = 24.0;
    final double graphHeight = height - topPadding - bottomPadding;

    // Draw horizontal grid lines (0%, 25%, 50%, 75%, 100%)
    final gridLevels = [0.0, 0.25, 0.5, 0.75, 1.0];
    for (final lvl in gridLevels) {
      final y = topPadding + graphHeight * (1.0 - lvl);
      canvas.drawLine(Offset(0, y), Offset(width, y), paintGrid);
    }

    // X step size
    final int pointsCount = dataPoints.length;
    final double stepX = pointsCount > 1 ? width / (pointsCount - 1) : width;

    // Compute coordinates
    final points = <Offset>[];
    for (int i = 0; i < pointsCount; i++) {
      final rate = dataPoints[i].value;
      final x = i * stepX;
      final y = topPadding + graphHeight * (1.0 - rate);
      points.add(Offset(x, y));
    }

    // Draw area under line
    if (points.isNotEmpty) {
      final fillPath = Path()
        ..moveTo(0, height - bottomPadding);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, height - bottomPadding);
      fillPath.close();

      // Simple gradient fill
      paintFill.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.18),
          theme.colorScheme.primary.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTRB(0, topPadding, width, height - bottomPadding));
      
      canvas.drawPath(fillPath, paintFill);
    }

    // Draw line connecting points
    if (pointsCount > 1) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, paintLine);
    }

    // Draw dots and text labels
    final monthFormat = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (int i = 0; i < pointsCount; i++) {
      final pt = points[i];
      final rate = dataPoints[i].value;
      final date = dataPoints[i].key;

      // Draw dot
      canvas.drawCircle(pt, 5.0, paintDot);
      canvas.drawCircle(pt, 3.0, Paint()..color = Colors.white);

      // Value label on top
      final textPainterVal = TextPainter(
        text: TextSpan(
          text: '${(rate * 100).round()}%',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainterVal.paint(
        canvas, 
        Offset(pt.dx - textPainterVal.width / 2, pt.dy - 16.0),
      );

      // Date label at the bottom
      final dateStr = '${date.day} ${monthFormat[date.month - 1]}';
      final textPainterDate = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // Keep dates within canvas boundary
      double xPos = pt.dx - textPainterDate.width / 2;
      if (xPos < 0) xPos = 0;
      if (xPos + textPainterDate.width > width) xPos = width - textPainterDate.width;

      textPainterDate.paint(
        canvas,
        Offset(xPos, height - bottomPadding + 6.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
