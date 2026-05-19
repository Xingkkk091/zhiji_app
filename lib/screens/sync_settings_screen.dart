import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import '../services/calendar_sync.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _sync = CalendarSync();
  bool _enabled = false;
  String? _selectedCalId;
  List<Calendar> _calendars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _enabled = await _sync.isEnabled();
    _selectedCalId = await _sync.getTargetCalendarId();
    final hasPerm = await _sync.hasPermission();
    if (hasPerm) {
      _calendars = await _sync.listCalendars();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleEnabled(bool v) async {
    if (v) {
      final ok = await _sync.requestPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒授權行事曆讀寫權限')),
        );
        return;
      }
      _calendars = await _sync.listCalendars();
    }
    await _sync.setEnabled(v);
    if (mounted) setState(() => _enabled = v);
  }

  Future<void> _pickCalendar(String id) async {
    await _sync.setTargetCalendarId(id);
    if (mounted) setState(() => _selectedCalId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行事曆同步')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: _toggleEnabled,
                  title: const Text('同步到系統行事曆'),
                  subtitle: const Text('智記事件會自動寫入你選的行事曆 (Google / Samsung 等)'),
                  secondary: const Icon(Icons.sync),
                ),
                if (_enabled) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('選擇要同步到哪個行事曆',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_calendars.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('沒有找到可寫入的行事曆。請先在手機加入 Google 帳號或建一個本地行事曆。',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._calendars.map((c) {
                      final selected = _selectedCalId == c.id;
                      return ListTile(
                        onTap: c.id == null ? null : () => _pickCalendar(c.id!),
                        leading: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.color != null ? Color(c.color!) : Colors.grey,
                          ),
                        ),
                        title: Text(c.name ?? '(無名)'),
                        subtitle: Text(c.accountName ?? c.accountType ?? ''),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Color(0xFF5B8DEF))
                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                      );
                    }),
                ],
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '💡 啟用後，之後新增/編輯/刪除事件都會自動同步\n'
                    '💡 已存在的舊事件不會自動補同步 (之後手動編輯一次即可)\n'
                    '💡 系統行事曆的更動「不會」回流到智記',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}
