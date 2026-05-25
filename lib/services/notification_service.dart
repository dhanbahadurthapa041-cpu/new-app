import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      // 1. Initialize timezone databases
      tz.initializeTimeZones();
      // Default local to Asia/Kathmandu (Nepal Time) since GMT offset is +5:45
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
      } catch (_) {
        // Fallback to default local
      }

      // 2. Set up Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. Set up iOS/Darwin initialization settings
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      // 4. Initialize notifications plugin
      await _notificationsPlugin.initialize(
        initializationSettings,
      );
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final iosPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        final granted = await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('NotificationService requestPermissions failed: $e');
    }

    return false;
  }

  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      // Cancel any existing reminder first to prevent multiple duplicates
      await cancelAllReminders();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time is in the past today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        0,
        'Mark Attendance Reminder',
        "Don't forget to take attendance for your classes today!",
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'attendance_reminder_channel_id',
            'Daily Attendance Reminders',
            channelDescription: 'Channel reminding you to record daily student attendance',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at set time
      );
    } catch (e) {
      debugPrint('NotificationService scheduleDailyReminder failed: $e');
    }
  }

  static Future<void> cancelAllReminders() async {
    try {
      await _notificationsPlugin.cancel(0);
    } catch (e) {
      debugPrint('NotificationService cancelAllReminders failed: $e');
    }
  }
}
