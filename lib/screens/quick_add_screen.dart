import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../services/notifications.dart';
import '../services/storage.dart';
import '../utils/parser.dart';

/// 從懸浮球或外部 share 進來的快速記事介面。
/// 解析時間、預覽事件、一鍵儲存。
class QuickAddScreen extends StatefulWidget {
  final String? initialText;
  const QuickAddScreen({super.key, this.initialText});

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final _ctrl = TextEditingController();
  final _storage = Storage();
  ParsedEvent? _parsed;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _ctrl.text = widget.initialText!;
      _reparse();
    } else {
      _pasteIfHasText();
    }
    _ctrl.addListener(_reparse);
  }

  Future<void> _pasteIfHasText() async {
    final d = await Clipboard.getData('text/plain');
    final t = d?.text?.trim();
    if (t != null && t.isNotEmpty && _ctrl.text.isEmpty) {
      _ctrl.text = t;
      _reparse();
    }
  }

  void _reparse() {
    final t = _ctrl.text.trim();
    setState(() => _parsed = t.isEmpty ? null : SmartParser.parse(t));
  }

  Future<void> _save() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final p = SmartParser.parse(t);
    final events = await _storage.loadAll();
    final ev = CalendarEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: p.title,
      notes: t == p.title ? null : t,
      when: p.when,
      hasReminder: true,
      category: p.category,
    );
    events.add(ev);
    await _storage.saveAll(events);
    await NotificationService.instance.scheduleFor(ev);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('快速記事'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _ctrl.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例：明天下午3點開會 / 記得買牛奶 / 5月20日10:00看牙醫',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            if (_parsed != null) _Preview(p: _parsed!),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _ctrl.text.trim().isEmpty ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('儲存並關閉'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final ParsedEvent p;
  const _Preview({required this.p});

  String _emoji() {
    switch (p.category) {
      case EventCategory.todo: return '✅';
      case EventCategory.idea: return '💡';
      case EventCategory.memo: return '📌';
      case EventCategory.important: return '⭐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = p.when;
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
    return Card(
      color: const Color(0x115B8DEF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5B8DEF)),
              const SizedBox(width: 6),
              Text('解析結果', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Text('${_emoji()} ${p.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('🕒 $ts', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
