import 'package:device_calendar/device_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/event.dart';

/// 把智記的事件寫到手機的系統行事曆 (Google Calendar / Samsung / etc.)
class CalendarSync {
  static const _kCalendarIdKey = 'zhiji_target_calendar_id';
  static const _kEnabledKey = 'zhiji_sync_enabled';

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  /// 請求權限。
  Future<bool> requestPermission() async {
    final r = await _plugin.requestPermissions();
    return r.data ?? false;
  }

  Future<bool> hasPermission() async {
    final r = await _plugin.hasPermissions();
    return r.data ?? false;
  }

  /// 列出手機上所有可寫入的行事曆。
  Future<List<Calendar>> listCalendars() async {
    final r = await _plugin.retrieveCalendars();
    final list = r.data?.where((c) => c.isReadOnly == false).toList() ?? [];
    return list;
  }

  Future<bool> isEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabledKey, v);
  }

  Future<String?> getTargetCalendarId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kCalendarIdKey);
  }

  Future<void> setTargetCalendarId(String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCalendarIdKey, id);
  }

  /// 寫入或更新事件到系統行事曆。
  /// 回傳系統的 event id (可存回事件做後續更新)。
  Future<String?> upsertEvent(CalendarEvent e, {String? existingSystemId}) async {
    if (!await isEnabled()) return null;
    if (!await hasPermission()) {
      final ok = await requestPermission();
      if (!ok) return null;
    }
    final calId = await getTargetCalendarId();
    if (calId == null || calId.isEmpty) return null;

    final ev = Event(
      calId,
      eventId: existingSystemId,
      title: e.title,
      description: e.notes,
      start: tz.TZDateTime.from(e.when, tz.local),
      end: tz.TZDateTime.from(e.when.add(const Duration(hours: 1)), tz.local),
      reminders: e.hasReminder ? [Reminder(minutes: 10)] : [],
    );

    final r = await _plugin.createOrUpdateEvent(ev);
    return r?.data;
  }

  Future<void> deleteEvent(String systemEventId) async {
    if (!await isEnabled()) return;
    final calId = await getTargetCalendarId();
    if (calId == null) return;
    await _plugin.deleteEvent(calId, systemEventId);
  }
}
