import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/event.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // 預設台北時區；實際時區由系統設定推導
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    // Android 13+ runtime permission
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleFor(CalendarEvent e) async {
    if (!e.hasReminder) return;
    final now = DateTime.now();
    if (e.when.isBefore(now)) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'zhiji_reminders',
        '行事曆提醒',
        channelDescription: '智記行事曆事件提醒',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      e.id.hashCode & 0x7FFFFFFF,
      e.title,
      e.notes ?? '行事曆提醒',
      tz.TZDateTime.from(e.when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelFor(String eventId) async {
    await _plugin.cancel(eventId.hashCode & 0x7FFFFFFF);
  }

  Future<void> rescheduleAll(List<CalendarEvent> events) async {
    await _plugin.cancelAll();
    for (final e in events) {
      if (e.hasReminder && !e.done) await scheduleFor(e);
    }
  }
}
