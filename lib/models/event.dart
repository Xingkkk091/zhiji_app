import 'dart:convert';

enum EventCategory { todo, idea, memo, important }

EventCategory categoryFromString(String s) =>
    EventCategory.values.firstWhere((e) => e.name == s, orElse: () => EventCategory.memo);

class CalendarEvent {
  final String id;
  String title;
  String? notes;
  DateTime when;
  bool hasReminder;
  bool done;
  EventCategory category;
  DateTime createdAt;
  String? systemEventId; // 在系統行事曆 (Google) 同步後的 id

  CalendarEvent({
    required this.id,
    required this.title,
    required this.when,
    this.notes,
    this.hasReminder = false,
    this.done = false,
    this.category = EventCategory.memo,
    DateTime? createdAt,
    this.systemEventId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'when': when.toIso8601String(),
        'hasReminder': hasReminder,
        'done': done,
        'category': category.name,
        'createdAt': createdAt.toIso8601String(),
        'systemEventId': systemEventId,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        notes: j['notes'] as String?,
        when: DateTime.parse(j['when'] as String),
        hasReminder: j['hasReminder'] as bool? ?? false,
        done: j['done'] as bool? ?? false,
        category: categoryFromString(j['category'] as String? ?? 'memo'),
        createdAt: DateTime.parse(j['createdAt'] as String),
        systemEventId: j['systemEventId'] as String?,
      );

  static String encodeList(List<CalendarEvent> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<CalendarEvent> decodeList(String s) {
    final raw = jsonDecode(s) as List<dynamic>;
    return raw.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
}
