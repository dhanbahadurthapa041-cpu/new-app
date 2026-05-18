import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';

void main() {
  testWidgets('shows the attendance dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AttendanceApp());

    expect(find.text('Attendance Dashboard'), findsOneWidget);
    expect(find.text('Welcome to the Attendance App'), findsOneWidget);
    expect(find.text('Mark Attendance'), findsOneWidget);
  });

  testWidgets('warns before switching dates with unsaved attendance', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AttendanceApp());
    await tester.tap(find.text('Mark Attendance'));
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
    await tester.tap(find.text('Mark Attendance'));
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
    await tester.tap(find.text('Mark Attendance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });
}
