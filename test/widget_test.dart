import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/storage_service.dart';

void main() {
  testWidgets('shows a dashboard loading state before local data resolves', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AttendanceApp());

    expect(find.text('Preparing dashboard'), findsOneWidget);
    expect(find.text('Loading roster and recent attendance'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Today\'s Attendance Rate'), findsOneWidget);
  });

  testWidgets('shows the attendance dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

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
    final todayKey = StorageService.attendanceKeyForDate(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'student_roster': 'not-json',
      todayKey: 'not-json',
    });

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Shree Bhawani Academy'), findsOneWidget);
    expect(find.text('No attendance saved yet today'), findsOneWidget);
    expect(find.text('Start Today\'s Attendance'), findsOneWidget);
  });

  testWidgets('warns before switching dates with unsaved attendance', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

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
    SharedPreferences.setMockInitialValues({});

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
    SharedPreferences.setMockInitialValues({});

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
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // 1. Navigate to Manage Roster from Home Screen AppBar
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Manage School Roster'), findsOneWidget);
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
}
