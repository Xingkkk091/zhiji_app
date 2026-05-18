import 'package:workmanager/workmanager.dart';
import 'storage.dart';
import 'notifications.dart';

const _kPeriodicTask = 'zhiji_periodic_check';

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final storage = Storage();
      final events = await storage.loadAll();
      await NotificationService.instance.init();
      // 為未來尚未排程的提醒重新對齊
      await NotificationService.instance.rescheduleAll(events);
    } catch (_) {}
    return true;
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(backgroundDispatcher, isInDebugMode: false);
    // 每 15 分鐘檢查一次（Android WorkManager 最低週期）
    await Workmanager().registerPeriodicTask(
      _kPeriodicTask,
      _kPeriodicTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.not_required),
    );
  }
}
