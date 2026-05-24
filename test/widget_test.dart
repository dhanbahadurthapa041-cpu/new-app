import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/storage_service.dart';

final demoStudents = [
  {
    'id': '1',
    'name': 'Aarav Sharma',
    'rollNumber': '101',
    'isPresent': true,
    'isLate': false,
  },
  {
    'id': '2',
    'name': 'Bipasha Thapa',
    'rollNumber': '102',
    'isPresent': true,
    'isLate': false,
  },
  {
    'id': '3',
    'name': 'Chirag Shrestha',
    'rollNumber': '103',
    'isPresent': true,
    'isLate': false,
  },
  {
    'id': '4',
    'name': 'Diya Maharjan',
    'rollNumber': '104',
    'isPresent': true,
    'isLate': false,
  },
  {
    'id': '5',
    'name': 'Elisha Gurung',
    'rollNumber': '105',
    'isPresent': true,
    'isLate': false,
  },
];

void setConfiguredPrefs() {
  SharedPreferences.setMockInitialValues({
    'school_name': 'Shree Bhawani Academy',
    'classes_list': jsonEncode([
      {'id': 'grade_10', 'name': 'Grade 10'},
      {'id': 'grade_9', 'name': 'Grade 9'},
    ]),
    'selected_class_id': 'grade_10',
    'roster_grade_10': jsonEncode(demoStudents),
    'roster_grade_9': jsonEncode([
      {
        'id': 'g9_1',
        'name': 'Kamal Thapa',
        'rollNumber': '901',
        'isPresent': true,
        'isLate': false,
      },
    ]),
  });
}

void main() {
  testWidgets('shows first-run setup when no local setup exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    expect(find.text('Set Up Attendance'), findsOneWidget);
    expect(find.text('School Name'), findsOneWidget);
    expect(find.text('First Class'), findsOneWidget);
  });

  testWidgets('shows a dashboard loading state before local data resolves', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Today\'s Attendance Rate'), findsOneWidget);
  });

  testWidgets('shows the attendance dashboard', (WidgetTester tester) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    expect(find.text('Shree Bhawani Academy'), findsOneWidget);
    expect(find.text('Today\'s Attendance Rate'), findsOneWidget);
    expect(find.text('Quick Metrics'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Start Today\'s Attendance'), findsOneWidget);
  });

  testWidgets('corrupt local storage does not block startup', (
    WidgetTester tester,
  ) async {
    final todayKey = StorageService.attendanceKeyForDate(
      'default_class',
      DateTime.now(),
    );
    SharedPreferences.setMockInitialValues({
      'student_roster': 'not-json',
      todayKey: 'not-json',
    });

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('My School'), findsOneWidget);
    expect(find.text('No attendance saved yet today'), findsOneWidget);
    expect(find.text('Start Today\'s Attendance'), findsOneWidget);
  });

  testWidgets('warns before switching dates with unsaved attendance', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Today\'s Attendance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      find.text(
        'You have attendance changes that have not been submitted yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks a student late and updates the daily summary', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Today\'s Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Summary'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('0/5'), findsNWidgets(2));

    await tester.tap(find.byType(Radio<bool>).at(1));
    await tester.pump();

    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('warns before leaving with unsaved attendance', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Today\'s Attendance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });

  testWidgets('can add and remove students on the roster screen', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // 1. Navigate to Manage Roster from Home Screen AppBar
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Manage Class Roster'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Bipasha Thapa'), findsOneWidget);

    // 2. Open Add Student dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add Student'), findsNWidgets(2));

    // 3. Fill details and submit
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Gaurav Karki',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Roll Number'),
      '106',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // 4. Verify Gaurav Karki is added
    expect(find.text('Gaurav Karki'), findsOneWidget);
    expect(find.text('Roll Number: 106'), findsOneWidget);

    // 5. Remove the first student (Aarav Sharma, roll 101)
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // Confirm removal
    expect(find.text('Remove Student?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    // Verify Aarav Sharma is removed from screen
    expect(find.text('Aarav Sharma'), findsNothing);
  });

  testWidgets('can switch classes and load different rosters/dashboards', (
    WidgetTester tester,
  ) async {
    setConfiguredPrefs();

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // 1. Initially Grade 10 is active
    expect(find.text('Grade 10'), findsOneWidget);

    // 2. Open the bottom sheet class selection by tapping the class dropdown
    await tester.tap(find.text('Grade 10'));
    await tester.pumpAndSettle();

    expect(find.text('Select Class'), findsOneWidget);
    expect(find.text('Grade 9'), findsOneWidget);

    // 3. Tap on Grade 9 in the bottom sheet list
    await tester.tap(find.text('Grade 9').last);
    await tester.pumpAndSettle();

    // 4. Verify class has switched to Grade 9
    expect(find.text('Grade 9'), findsOneWidget);
    expect(find.text('Grade 10'), findsNothing);
  });

  testWidgets(
    'tapping recent activity navigates to historical attendance screen',
    (WidgetTester tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final pastKey = StorageService.attendanceKeyForDate('grade_10', pastDate);

      final months = [
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
      final formattedPastDate =
          '${months[pastDate.month - 1]} ${pastDate.day}, ${pastDate.year}';

      final mockStudents = [
        {
          'id': '1',
          'name': 'Aarav Sharma',
          'rollNumber': '101',
          'isPresent': true,
          'isLate': false,
        },
        {
          'id': '2',
          'name': 'Bipasha Thapa',
          'rollNumber': '102',
          'isPresent': false,
          'isLate': false,
        },
      ];

      SharedPreferences.setMockInitialValues({
        'school_name': 'Shree Bhawani Academy',
        'classes_list': jsonEncode([
          {'id': 'grade_10', 'name': 'Grade 10'},
        ]),
        'selected_class_id': 'grade_10',
        'roster_grade_10': jsonEncode(mockStudents),
        pastKey: jsonEncode(mockStudents),
      });

      await tester.pumpWidget(const AttendanceApp());
      await tester.pumpAndSettle();

      // Verify recent activity list shows the past date
      expect(find.text(formattedPastDate), findsOneWidget);
      expect(find.text('1 present, 0 late, 1 absent'), findsOneWidget);

      // Tap the recent activity item
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final itemFinder = find.text(formattedPastDate);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      // Verify we navigated to the AttendanceScreen for the past date
      expect(
        find.widgetWithText(OutlinedButton, formattedPastDate),
        findsOneWidget,
      );

      // Verify we can view this attendance
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bipasha Thapa'), findsOneWidget);
    },
  );
}
