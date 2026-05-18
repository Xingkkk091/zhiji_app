// Background reminder 完全由 flutter_local_notifications + Android AlarmManager 負責。
// 排程的鬧鐘是系統級別 (setExactAndAllowWhileIdle)，即使 App 被殺、裝置重開後，
// 也會在指定時間 fire — 不需要額外 WorkManager。
//
// 開機後恢復鬧鐘已透過 AndroidManifest 的 RECEIVE_BOOT_COMPLETED 權限 +
// flutter_local_notifications 內建 BootBroadcastReceiver 自動處理。

class BackgroundService {
  static Future<void> init() async {
    // no-op — 保留 API 以便未來擴充
  }
}
