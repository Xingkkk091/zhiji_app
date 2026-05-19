import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 前景服務任務 handler — 必須是頂層 class，由獨立 isolate 執行。
class ZhijiTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服務啟動 — 目前不做任何重活
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期 tick — 留作未來擴充 (例如重新對齊鬧鐘)
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // 服務被銷毀
  }

  @override
  void onReceiveData(Object data) {
    // 主 App 跨 isolate 傳資料進來
  }
}

@pragma('vm:entry-point')
void startZhijiTaskHandler() {
  FlutterForegroundTask.setTaskHandler(ZhijiTaskHandler());
}

class ForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zhiji_foreground',
        channelName: '智記背景服務',
        channelDescription: '保持智記在背景活著、確保提醒與懸浮球可用',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60 * 60 * 1000), // 每小時 tick 一次
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<bool> start() async {
    if (await isRunning()) return true;
    final res = await FlutterForegroundTask.startService(
      notificationTitle: '智記運作中',
      notificationText: '點來開啟 App',
      callback: startZhijiTaskHandler,
    );
    if (res is ServiceRequestSuccess) return true;
    if (kDebugMode) debugPrint('foreground start failed: $res');
    return false;
  }

  static Future<bool> stop() async {
    if (!await isRunning()) return true;
    final res = await FlutterForegroundTask.stopService();
    return res is ServiceRequestSuccess;
  }
}
