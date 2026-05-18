# 智記 — Flutter 行事曆 + 智能記錄

Android / iOS 雙平台。把任何文字（自己打的、別處複製的、從別 App 分享的）
自動解析時間 → 寫入行事曆 → 到時間在背景跳通知提醒。

## 核心功能

| 功能 | 說明 |
|---|---|
| 📅 行事曆 | 月 / 週視圖，每天事件顯示紅點，點日期看當天所有事件 |
| ✨ 智能解析 | 「明天下午3點開會」「5/20 10:00 看牙醫」「記得買牛奶」自動抓出時間 + 分類 |
| 📤 分享進入 | 在 Chrome / LINE / Notes 等任何 App **長按文字 → 分享 → 智記**，自動帶入文字並解析 |
| 📋 PROCESS_TEXT | 選取文字後系統選單也能直接傳進智記 |
| 🔔 背景通知 | 到時間自動通知（用 Android `AlarmManager` exact alarm + WorkManager 定時對齊）|
| 📝 4 種分類 | ✅ 待辦 / 💡 想法 / 📌 備忘 / ⭐ 重要，自動偵測 |
| 💾 本地儲存 | `shared_preferences` 純本地，不上雲，資料留在手機 |
| 🌗 深色模式 | 跟隨系統 |

## 結構

```
lib/
  main.dart                  進入點：初始化通知 / 背景任務
  models/event.dart          CalendarEvent + JSON
  services/
    storage.dart             shared_preferences 讀寫
    notifications.dart       flutter_local_notifications 排程通知
    background.dart          workmanager 背景每 15 分鐘對齊
  utils/parser.dart          中文時間 / 分類解析器
  screens/
    home_screen.dart         月曆 + 當日清單 + 分享 intent
    event_editor.dart        新增 / 編輯事件畫面
test/widget_test.dart        解析器單元測試
android/app/src/main/AndroidManifest.xml   分享 intent filter + 權限
android/app/build.gradle.kts               minSdk 23 + desugaring
```

## 在手機上跑（最快流程）

### 一次性準備 Android 工具鏈

`flutter doctor` 目前顯示缺 `cmdline-tools`：

```powershell
# 方法 A：安裝 Android Studio (推薦) → 開啟一次它會自動下載 cmdline-tools
# https://developer.android.com/studio

# 方法 B：只裝 command-line tools
#   1) 下載 https://developer.android.com/studio#command-line-tools-only
#   2) 解壓到 %LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\
#   3) 設環境變數: ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk

# 然後接受授權
$env:Path = "C:\Users\User\flutter\bin;$env:Path"
flutter doctor --android-licenses    # 全部按 y
flutter doctor                       # 確認 Android toolchain 變綠
```

### 接手機 USB（開啟「USB 偵錯」）直接執行

```powershell
$env:Path = "C:\Users\User\flutter\bin;$env:Path"
cd "C:\Users\User\Desktop\新增資料夾 (8)\zhiji_app"
flutter devices                # 確認手機被偵測到
flutter run                    # debug 模式直接裝到手機
```

### 打 APK 自己拖到手機安裝

```powershell
flutter build apk --release
# 輸出: build\app\outputs\flutter-apk\app-release.apk
# 用 USB / Google Drive / LINE 傳到手機 → 點開安裝（需允許「未知來源」）
```

## 用法

1. **直接新增**：右下 ➕，輸入「明天下午 3 點開會」→ 解析卡片亮起，時間和分類已自動填好 → 儲存
2. **從別 App 分享**：在任何 App 選文字 → 分享 → 選「智記」→ 自動帶入並解析
3. **從剪貼簿**：上方 📋 圖示，把複製的文字一鍵建立事件
4. **打勾完成**：待辦類事件右側有圓圈，點一下劃掉
5. **滑動刪除**：事件向左滑 → 刪除

## 智能解析支援

- **相對日期**：今天 / 明天 / 後天
- **週幾**：下週三 / 本週五 / 星期日
- **絕對日期**：5/20、5月20日、2026/5/20
- **時間**：15:30、下午3點、晚上8點半、上午10點
- **分類關鍵字**：
  - 待辦：記得 / 提醒 / 買 / 寄 / 打給 / 約 / 預約 / 繳…
  - 想法：想法 / 靈感 / 點子 / idea…
  - 重要：重要 / 緊急 / !! / 注意…
  - 都不是就歸「📌 備忘」

要加 / 改字詞 → [lib/utils/parser.dart](lib/utils/parser.dart) `_todoWords` 等常數。

## 背景行為怎麼運作

- **通知排程**：建立事件時，呼叫 `flutter_local_notifications.zonedSchedule()` 註冊一個系統級 AlarmManager 鬧鐘 → 即使 App 被殺也會準時跳出
- **WorkManager 定時對齊**：每 15 分鐘背景跑 [background.dart](lib/services/background.dart) → 重新對齊所有未發送的提醒（防止裝置重開後遺失）
- 已加入 `RECEIVE_BOOT_COMPLETED` 權限，開機後鬧鐘會自動恢復

## 已知限制

- **iOS**：share intent 需額外設定 App Group + Share Extension（[receive_sharing_intent 文件](https://pub.dev/packages/receive_sharing_intent)）。目前只配好 Android。
- **iOS 背景**：iOS 限制嚴，背景對齊頻率受系統決定（最短 15 分鐘）
- **電池優化**：部分 Android 廠商（小米 / OPPO / Vivo）會殺背景，請在系統設定把「智記」加入「不省電」白名單

## TODO（之後可擴充）

- [ ] 語音輸入（`speech_to_text` 套件）說話直接建事件
- [ ] 整合 Claude API 做更準的自然語解析（目前是 regex）
- [ ] 雲端同步（Supabase / Firebase）
- [ ] 行事曆匯出 .ics 給 Google Calendar
- [ ] 重複事件（每週一、每月 1 號…）
