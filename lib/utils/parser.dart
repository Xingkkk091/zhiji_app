import '../models/event.dart';

class ParsedEvent {
  final String title;
  final DateTime when;
  final EventCategory category;
  const ParsedEvent({required this.title, required this.when, required this.category});
}

/// 從一段自然語文字中試著抽出 (標題, 時間, 分類).
/// 找不到時間時，回傳一個合理的預設（今天的下一個整點或當下）。
class SmartParser {
  static const _todoWords = ['待辦', '要做', '記得', '提醒', '別忘', '不要忘', '買', '寄', '打給', '聯絡', '完成', '繳', '預約', '約', 'todo'];
  static const _ideaWords = ['想法', '靈感', '點子', 'idea', '或許', '也許', '構想'];
  static const _importantWords = ['重要', '緊急', '!!', '！！', '注意', '小心', 'urgent'];

  static ParsedEvent parse(String input, {DateTime? now}) {
    final src = input.trim();
    now ??= DateTime.now();

    final when = _extractDateTime(src, now) ?? _nextRoundHour(now);
    final title = _cleanTitle(src);
    final category = _classify(src.toLowerCase());

    return ParsedEvent(title: title, when: when, category: category);
  }

  static EventCategory _classify(String lower) {
    for (final w in _importantWords) {
      if (lower.contains(w.toLowerCase())) return EventCategory.important;
    }
    for (final w in _todoWords) {
      if (lower.contains(w.toLowerCase())) return EventCategory.todo;
    }
    for (final w in _ideaWords) {
      if (lower.contains(w.toLowerCase())) return EventCategory.idea;
    }
    return EventCategory.memo;
  }

  static DateTime _nextRoundHour(DateTime now) {
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  /// 嘗試從文字找出日期 + 時間。支援中文常用詞。
  static DateTime? _extractDateTime(String src, DateTime now) {
    DateTime base = DateTime(now.year, now.month, now.day);
    int? hour;
    int? minute;
    bool dateFound = false;

    // 1. 相對日期
    if (src.contains('後天')) {
      base = base.add(const Duration(days: 2));
      dateFound = true;
    } else if (src.contains('明天') || src.contains('明日')) {
      base = base.add(const Duration(days: 1));
      dateFound = true;
    } else if (src.contains('今天') || src.contains('今日')) {
      dateFound = true;
    } else {
      // 「下週X」「這週X」「星期X」
      final wk = RegExp(r'(下週|下周|這週|这周|本週|本周|星期|週|周)([一二三四五六日天])').firstMatch(src);
      if (wk != null) {
        final prefix = wk.group(1)!;
        final dayChar = wk.group(2)!;
        final target = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7}[dayChar]!;
        int diff = target - now.weekday;
        if (prefix.contains('下')) {
          diff += 7;
        } else if (diff < 0) {
          diff += 7;
        }
        base = base.add(Duration(days: diff));
        dateFound = true;
      }
    }

    // 2. 明確日期：M/D 或 M月D日 或 YYYY/M/D
    final ymd = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(src);
    if (ymd != null) {
      base = DateTime(int.parse(ymd.group(1)!), int.parse(ymd.group(2)!), int.parse(ymd.group(3)!));
      dateFound = true;
    } else {
      final md1 = RegExp(r'(\d{1,2})[/-](\d{1,2})(?!\d)').firstMatch(src);
      final md2 = RegExp(r'(\d{1,2})月(\d{1,2})[日號号]?').firstMatch(src);
      final md = md2 ?? md1;
      if (md != null) {
        final m = int.parse(md.group(1)!);
        final d = int.parse(md.group(2)!);
        var year = now.year;
        final cand = DateTime(year, m, d);
        if (cand.isBefore(DateTime(now.year, now.month, now.day))) year += 1;
        base = DateTime(year, m, d);
        dateFound = true;
      }
    }

    // 3. 時間：HH:MM / 上午X點 / 下午X點 / 晚上X點 / X點半
    final hm = RegExp(r'(\d{1,2})[:：](\d{2})').firstMatch(src);
    if (hm != null) {
      hour = int.parse(hm.group(1)!);
      minute = int.parse(hm.group(2)!);
      if (RegExp(r'(下午|晚上|傍晚|pm|PM)').hasMatch(src) && hour < 12) hour += 12;
    } else {
      final cn = RegExp(r'(上午|早上|凌晨|中午|下午|晚上|傍晚)?(\d{1,2})點(半|十五分|三十分|\d{1,2}分)?').firstMatch(src);
      if (cn != null) {
        final period = cn.group(1);
        hour = int.parse(cn.group(2)!);
        final mPart = cn.group(3);
        if (mPart == '半') {
          minute = 30;
        } else if (mPart != null) {
          final m = RegExp(r'(\d{1,2})').firstMatch(mPart);
          if (m != null) minute = int.parse(m.group(1)!);
        } else {
          minute = 0;
        }
        if ((period == '下午' || period == '晚上' || period == '傍晚') && hour < 12) hour += 12;
        if (period == '凌晨' && hour == 12) hour = 0;
        if (period == '中午' && hour < 12) hour = 12;
      }
    }

    if (!dateFound && hour == null) return null;

    hour ??= 9; // 預設提醒時間：早上 9 點
    minute ??= 0;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  static String _cleanTitle(String src) {
    var t = src;
    // 去掉常見的時間表述
    final patterns = [
      RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}'),
      RegExp(r'\d{1,2}[/-]\d{1,2}'),
      RegExp(r'\d{1,2}月\d{1,2}[日號号]?'),
      RegExp(r'(下週|下周|這週|这周|本週|本周|星期|週|周)[一二三四五六日天]'),
      RegExp(r'(後天|明天|明日|今天|今日)'),
      RegExp(r'\d{1,2}[:：]\d{2}'),
      RegExp(r'(上午|早上|凌晨|中午|下午|晚上|傍晚)?\d{1,2}點(半|十五分|三十分|\d{1,2}分)?'),
      RegExp(r'(記得|提醒|別忘了|別忘|不要忘記|不要忘)'),
    ];
    for (final p in patterns) {
      t = t.replaceAll(p, ' ');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) t = src.trim();
    return t.length > 80 ? '${t.substring(0, 80)}…' : t;
  }
}
