import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/parser.dart';

class EventEditor extends StatefulWidget {
  final CalendarEvent? existing;
  final String? prefillText;
  final DateTime? prefillDate;

  const EventEditor({super.key, this.existing, this.prefillText, this.prefillDate});

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _when;
  late bool _reminder;
  late EventCategory _category;
  bool _parsedFromText = false;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      final e = widget.existing!;
      _titleCtrl = TextEditingController(text: e.title);
      _notesCtrl = TextEditingController(text: e.notes ?? '');
      _when = e.when;
      _reminder = e.hasReminder;
      _category = e.category;
    } else if (widget.prefillText != null && widget.prefillText!.trim().isNotEmpty) {
      final parsed = SmartParser.parse(widget.prefillText!);
      _titleCtrl = TextEditingController(text: parsed.title);
      _notesCtrl = TextEditingController(text: widget.prefillText);
      _when = parsed.when;
      _reminder = parsed.category == EventCategory.todo || parsed.category == EventCategory.important;
      _category = parsed.category;
      _parsedFromText = true;
    } else {
      _titleCtrl = TextEditingController();
      _notesCtrl = TextEditingController();
      final base = widget.prefillDate ?? DateTime.now();
      final now = DateTime.now();
      _when = DateTime(base.year, base.month, base.day, now.hour + 1, 0);
      _reminder = false;
      _category = EventCategory.memo;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t != null) {
      setState(() {
        _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute);
      });
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入標題')),
      );
      return;
    }

    final result = CalendarEvent(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      when: _when,
      hasReminder: _reminder,
      done: widget.existing?.done ?? false,
      category: _category,
      createdAt: widget.existing?.createdAt,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final df = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
    final tf = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '編輯事件' : '新增事件'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('儲存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_parsedFromText)
            Card(
              color: Colors.blue.withValues(alpha: 0.08),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('已自動解析時間與分類，可手動調整', style: TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
          if (_parsedFromText) const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '標題',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: '備註',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(df.format(_when)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(tf.format(_when)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('分類', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: EventCategory.values.map((c) {
              return ChoiceChip(
                label: Text(_categoryLabel(c)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
            title: const Text('提醒我'),
            subtitle: Text(_reminder ? '會在 ${df.format(_when)} ${tf.format(_when)} 通知' : '到時不會通知'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  static String _categoryLabel(EventCategory c) {
    switch (c) {
      case EventCategory.todo:
        return '✅ 待辦';
      case EventCategory.idea:
        return '💡 想法';
      case EventCategory.memo:
        return '📌 備忘';
      case EventCategory.important:
        return '⭐ 重要';
    }
  }
}
