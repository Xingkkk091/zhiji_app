import 'package:flutter_test/flutter_test.dart';
import 'package:zhiji/utils/parser.dart';

void main() {
  test('SmartParser parses "明天下午3點開會"', () {
    final now = DateTime(2026, 5, 18, 10, 0);
    final p = SmartParser.parse('明天下午3點開會', now: now);
    expect(p.when.day, 19);
    expect(p.when.hour, 15);
    expect(p.title.contains('開會'), true);
  });

  test('SmartParser detects todo keyword', () {
    final p = SmartParser.parse('記得買牛奶');
    expect(p.title.contains('買牛奶'), true);
  });
}
