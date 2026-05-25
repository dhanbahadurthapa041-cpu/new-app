import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/student_model.dart';
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
    expect(find.text('Start Today\'s Attendance'), findsOneWidget);

    // Scroll to bring Recent Activity into view
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Recent Activity'), findsOneWidget);
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

      // Scroll to bring Recent Activity into view
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify recent activity list shows the past date
      expect(find.text(formattedPastDate), findsOneWidget);
      expect(find.text('1 present, 0 late, 1 absent'), findsOneWidget);

      // Tap the recent activity item
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

  group('StorageService Export/Import tests', () {
    test('can export class data to JSON and import it back', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      
      // 1. Create a class
      final classModel = await StorageService.createClass('Grade 12');
      final classId = classModel.id;

      // 2. Set roster
      final students = [
        Student(id: 's1', name: 'John Doe', rollNumber: '1', isPresent: true, isLate: false),
        Student(id: 's2', name: 'Jane Smith', rollNumber: '2', isPresent: true, isLate: false),
      ];
      await StorageService.saveMasterRoster(classId, students);

      // 3. Save some attendance records
      final date1 = DateTime(2026, 5, 23);
      students[0].isPresent = true;
      students[0].isLate = false;
      students[1].isPresent = false;
      students[1].isLate = false;
      await StorageService.saveAttendance(classId, students, date: date1);

      final date2 = DateTime(2026, 5, 24);
      students[0].isPresent = true;
      students[0].isLate = true;
      students[1].isPresent = true;
      students[1].isLate = false;
      await StorageService.saveAttendance(classId, students, date: date2);

      // 4. Export to JSON
      final jsonString = await StorageService.exportClassToJson(classId);
      expect(jsonString, contains('attendance_app_class_export'));
      expect(jsonString, contains('Grade 12'));
      expect(jsonString, contains('John Doe'));

      // 5. Import back from JSON
      await StorageService.importClassFromJson(jsonString);

      // 6. Verify imported class exists (unique name conflict resolution will rename it to 'Grade 12 (1)')
      final classes = await StorageService.loadClasses();
      expect(classes.length, equals(2));
      final importedClass = classes.firstWhere((c) => c.name == 'Grade 12 (1)');
      final importedClassId = importedClass.id;

      // 7. Verify roster
      final importedRoster = await StorageService.loadMasterRoster(importedClassId);
      expect(importedRoster.length, equals(2));
      expect(importedRoster[0].name, equals('John Doe'));
      expect(importedRoster[1].name, equals('Jane Smith'));

      // 8. Verify attendance records
      final records = await StorageService.loadAllAttendanceRecords(importedClassId);
      expect(records.length, equals(2));

      final importedDate1 = DateTime(2026, 5, 23);
      final list1 = records[importedDate1]!;
      expect(list1.firstWhere((s) => s.id == 's1').isPresent, isTrue);
      expect(list1.firstWhere((s) => s.id == 's1').isLate, isFalse);
      expect(list1.firstWhere((s) => s.id == 's2').isPresent, isFalse);

      final importedDate2 = DateTime(2026, 5, 24);
      final list2 = records[importedDate2]!;
      expect(list2.firstWhere((s) => s.id == 's1').isPresent, isTrue);
      expect(list2.firstWhere((s) => s.id == 's1').isLate, isTrue);
      expect(list2.firstWhere((s) => s.id == 's2').isPresent, isTrue);
      expect(list2.firstWhere((s) => s.id == 's2').isLate, isFalse);
    });

    test('can export class data to CSV format', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      
      final classModel = await StorageService.createClass('Grade 12');
      final classId = classModel.id;

      final students = [
        Student(id: 's1', name: 'John Doe', rollNumber: '1', isPresent: true, isLate: false),
        Student(id: 's2', name: 'Jane Smith', rollNumber: '2', isPresent: true, isLate: false),
      ];
      await StorageService.saveMasterRoster(classId, students);

      final date1 = DateTime(2026, 5, 23);
      students[0].isPresent = true;
      students[0].isLate = false;
      students[1].isPresent = false;
      students[1].isLate = false;
      await StorageService.saveAttendance(classId, students, date: date1);

      final csvString = await StorageService.exportClassToCsv(classId);
      expect(csvString, contains('Roll Number,Student Name,2026-05-23'));
      expect(csvString, contains('1,John Doe,Present'));
      expect(csvString, contains('2,Jane Smith,Absent'));
    });
  });
}
