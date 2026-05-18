import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

class Storage {
  static const _key = 'zhiji_events_v1';

  Future<List<CalendarEvent>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return CalendarEvent.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<CalendarEvent> events) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, CalendarEvent.encodeList(events));
  }
}
