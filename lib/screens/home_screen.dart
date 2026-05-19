import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/event.dart';
import '../services/foreground_service.dart';
import '../services/notifications.dart';
import '../services/overlay_service.dart';
import '../services/storage.dart';
import '../services/updater.dart';
import 'event_editor.dart';

const _kGithubOwner = 'Xingkkk091';
const _kGithubRepo = 'zhiji_app';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = Storage();
  List<CalendarEvent> _events = [];
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _calFormat = CalendarFormat.month;

  late StreamSubscription _shareSub;

  late final Updater _updater = Updater(owner: _kGithubOwner, repo: _kGithubRepo);

  @override
  void initState() {
    super.initState();
    _load();
    _initShare();
    // App 開啟靜默查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updater.checkAndPrompt(context, silent: true);
    });
  }

  Future<void> _load() async {
    final list = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _events = list);
  }

  void _initShare() {
    // App 已開啟時收到分享
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      _handleShared(files);
    }, onError: (_) {});

    // App 從關閉狀態被分享叫起
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleShared(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final text = files
        .where((f) => f.type == SharedMediaType.text || f.type == SharedMediaType.url)
        .map((f) => f.path)
        .join('\n')
        .trim();
    if (text.isEmpty) return;
    _openEditorForText(text);
  }

  Future<void> _openEditorForText(String text) async {
    final res = await Navigator.push<CalendarEvent>(
      context,
      MaterialPageRoute(builder: (_) => EventEditor(prefillText: text)),
    );
    if (res != null) await _addOrUpdate(res);
  }

  Future<void> _openEditorBlank({DateTime? date}) async {
    final res = await Navigator.push<CalendarEvent>(
      context,
      MaterialPageRoute(builder: (_) => EventEditor(prefillDate: date)),
    );
    if (res != null) await _addOrUpdate(res);
  }

  Future<void> _editExisting(CalendarEvent e) async {
    final res = await Navigator.push<CalendarEvent>(
      context,
      MaterialPageRoute(builder: (_) => EventEditor(existing: e)),
    );
    if (res != null) await _addOrUpdate(res);
  }

  Future<void> _addOrUpdate(CalendarEvent e) async {
    final idx = _events.indexWhere((x) => x.id == e.id);
    if (idx >= 0) {
      _events[idx] = e;
    } else {
      _events.add(e);
    }
    await _storage.saveAll(_events);
    if (e.hasReminder && !e.done) {
      await NotificationService.instance.cancelFor(e.id);
      await NotificationService.instance.scheduleFor(e);
    } else {
      await NotificationService.instance.cancelFor(e.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _delete(CalendarEvent e) async {
    _events.removeWhere((x) => x.id == e.id);
    await _storage.saveAll(_events);
    await NotificationService.instance.cancelFor(e.id);
    if (mounted) setState(() {});
  }

  Future<void> _toggleDone(CalendarEvent e) async {
    e.done = !e.done;
    await _storage.saveAll(_events);
    if (e.done) {
      await NotificationService.instance.cancelFor(e.id);
    } else if (e.hasReminder) {
      await NotificationService.instance.scheduleFor(e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openBackgroundSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _BackgroundSettingsSheet(),
    );
  }

  Future<void> _pasteAndCreate() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪貼簿沒有文字')),
      );
      return;
    }
    await _openEditorForText(text);
  }

  List<CalendarEvent> _eventsOf(DateTime day) {
    return _events.where((e) => isSameDay(e.when, day)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
  }

  @override
  void dispose() {
    _shareSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _eventsOf(_selected);
    final df = DateFormat('M/d (E)', 'zh_TW');

    return Scaffold(
      appBar: AppBar(
        title: const Text('智記'),
        actions: [
          IconButton(
            tooltip: '從剪貼簿建立',
            onPressed: _pasteAndCreate,
            icon: const Icon(Icons.content_paste_go),
          ),
          IconButton(
            tooltip: '懸浮球 / 背景服務',
            onPressed: _openBackgroundSettings,
            icon: const Icon(Icons.bubble_chart),
          ),
          IconButton(
            tooltip: '檢查更新',
            onPressed: () => _updater.checkAndPrompt(context),
            icon: const Icon(Icons.system_update_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focused,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              calendarFormat: _calFormat,
              eventLoader: _eventsOf,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'zh_TW',
              availableCalendarFormats: const {
                CalendarFormat.month: '月',
                CalendarFormat.twoWeeks: '兩週',
                CalendarFormat.week: '週',
              },
              onDaySelected: (sel, foc) {
                setState(() {
                  _selected = sel;
                  _focused = foc;
                });
              },
              onFormatChanged: (f) => setState(() => _calFormat = f),
              onPageChanged: (foc) => _focused = foc,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0x335B8DEF),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF5B8DEF),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 4,
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonShowsNext: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  df.format(_selected),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${today.length} 件事', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: today.isEmpty
                ? _EmptyToday(onAdd: () => _openEditorBlank(date: _selected))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: today.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _EventTile(
                      event: today[i],
                      onTap: () => _editExisting(today[i]),
                      onToggle: () => _toggleDone(today[i]),
                      onDelete: () => _delete(today[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditorBlank(date: _selected),
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _EventTile({
    required this.event,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  Color _color() {
    switch (event.category) {
      case EventCategory.todo:
        return const Color(0xFF10B981);
      case EventCategory.idea:
        return const Color(0xFFF59E0B);
      case EventCategory.memo:
        return const Color(0xFF6366F1);
      case EventCategory.important:
        return const Color(0xFFEF4444);
    }
  }

  String _emoji() {
    switch (event.category) {
      case EventCategory.todo:
        return '✅';
      case EventCategory.idea:
        return '💡';
      case EventCategory.memo:
        return '📌';
      case EventCategory.important:
        return '⭐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('HH:mm');
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('確定刪除？'),
                content: Text(event.title),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _color().withValues(alpha: 0.3)),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 4,
            decoration: BoxDecoration(
              color: _color(),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Text(
            '${_emoji()} ${event.title}',
            style: TextStyle(
              decoration: event.done ? TextDecoration.lineThrough : null,
              color: event.done ? Colors.grey : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(Icons.access_time, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(tf.format(event.when), style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              if (event.hasReminder) ...[
                const SizedBox(width: 10),
                const Icon(Icons.notifications_active, size: 13, color: Colors.orange),
              ],
              if (event.notes != null && event.notes!.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.notes, size: 13, color: Colors.grey),
              ],
            ],
          ),
          trailing: event.category == EventCategory.todo
              ? IconButton(
                  icon: Icon(
                    event.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: event.done ? Colors.green : Colors.grey,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyToday({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('這天還沒有事件', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增一件'),
          ),
        ],
      ),
    );
  }
}

class _BackgroundSettingsSheet extends StatefulWidget {
  const _BackgroundSettingsSheet();
  @override
  State<_BackgroundSettingsSheet> createState() => _BackgroundSettingsSheetState();
}

class _BackgroundSettingsSheetState extends State<_BackgroundSettingsSheet> {
  bool _bubbleOn = false;
  bool _serviceOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final b = await OverlayService.isShown();
    final s = await ForegroundService.isRunning();
    if (!mounted) return;
    setState(() {
      _bubbleOn = b;
      _serviceOn = s;
      _loading = false;
    });
  }

  Future<void> _toggleBubble(bool v) async {
    if (v) {
      final ok = await OverlayService.showBubble();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒授權「在其他 App 上顯示」就不能開懸浮球')),
        );
      }
    } else {
      await OverlayService.hideBubble();
    }
    await _refresh();
  }

  Future<void> _toggleService(bool v) async {
    if (v) {
      await ForegroundService.start();
    } else {
      await ForegroundService.stop();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('背景與懸浮球', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _bubbleOn,
              onChanged: _toggleBubble,
              title: const Text('懸浮球'),
              subtitle: const Text('任何 App 上都浮一顆球，點開即快速記事'),
              secondary: const Icon(Icons.circle_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _serviceOn,
              onChanged: _toggleService,
              title: const Text('背景服務'),
              subtitle: const Text('通知欄保持一條通知，防止系統殺掉 App'),
              secondary: const Icon(Icons.workspaces_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 首次開啟懸浮球會跳系統設定請你授權\n💡 中國品牌手機請額外把智記加入「自動啟動」與「電池無限制」',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
