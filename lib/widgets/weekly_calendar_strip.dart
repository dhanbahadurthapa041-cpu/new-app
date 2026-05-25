import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class WeeklyCalendarStrip extends StatefulWidget {
  final String classId;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeeklyCalendarStrip({
    required this.classId,
    required this.selectedDate,
    required this.onDateSelected,
    super.key,
  });

  @override
  State<WeeklyCalendarStrip> createState() => _WeeklyCalendarStripState();
}

class _WeeklyCalendarStripState extends State<WeeklyCalendarStrip> {
  List<DateTime> _weekDays = [];
  Set<DateTime> _savedDates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
    _loadSavedDates();
  }

  @override
  void didUpdateWidget(WeeklyCalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _generateWeekDays();
    _loadSavedDates();
  }

  void _generateWeekDays() {
    final now = widget.selectedDate;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    _weekDays = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _loadSavedDates() async {
    if (widget.classId.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final dates = await StorageService.loadClassSavedDates(widget.classId);
      if (mounted) {
        setState(() {
          _savedDates = dates;
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

  String _getWeekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This Week',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      children: [
                        _buildLegendDot(Colors.green, 'Saved'),
                        const SizedBox(width: 8),
                        _buildLegendDot(Colors.red, 'Missing'),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekDays.map((day) {
                final isSelected = day.year == widget.selectedDate.year &&
                    day.month == widget.selectedDate.month &&
                    day.day == widget.selectedDate.day;

                final isToday = _isToday(day);
                final isFuture = day.isAfter(DateTime.now());
                final hasAttendance = _savedDates.contains(day);

                Color indicatorColor = Colors.grey;
                if (!isFuture) {
                  indicatorColor = hasAttendance ? Colors.green : Colors.red;
                }

                return Expanded(
                  child: InkWell(
                    onTap: () => widget.onDateSelected(day),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : isToday
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                            : isToday
                                ? Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12), width: 1)
                                : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getWeekdayName(day.weekday),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day.day.toString(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFuture ? Colors.transparent : indicatorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }
}
