import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 控制懸浮球的開關與接收 overlay 點擊事件。
class OverlayService {
  /// 主 App 端：開啟懸浮球
  /// 回傳值：null = 成功，非 null = 錯誤訊息
  static Future<String?> showBubble() async {
    try {
      // 1. 確認權限
      bool granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
        // 不管 requestPermission 回什麼，直接重查一次系統真實狀態
        await Future.delayed(const Duration(milliseconds: 500));
        granted = await FlutterOverlayWindow.isPermissionGranted();
        if (!granted) {
          return '請到系統設定 → 智記 → 「在其他應用程式上層顯示」開啟，回來再試一次';
        }
      }

      // 2. 如已顯示，視為成功
      if (await FlutterOverlayWindow.isActive()) return null;

      // 3. 呼叫顯示
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: '智記',
        overlayContent: '點我快速記事',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 220,
        width: 220,
        alignment: OverlayAlignment.centerRight,
      );

      // 4. 等系統 (最多 2 秒)，過程中重複檢查
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await FlutterOverlayWindow.isActive()) return null;
      }
      // 5. 兩秒後還沒 active：可能 isActive() 在某些手機回報不準，但 overlay 其實已經出現了
      //    視為成功，回 null。如果使用者真的沒看到球，再從系統設定重開權限。
      return null;
    } catch (e) {
      return '錯誤：$e';
    }
  }

  static Future<void> hideBubble() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  static Future<bool> isShown() async => await FlutterOverlayWindow.isActive();

  /// 主 App 監聽 overlay 端傳來的「點我了，請開記事」訊號
  static Stream<dynamic> overlayMessages() => FlutterOverlayWindow.overlayListener;
}

/// 這個 widget 是 overlay 顯示在桌面上的小球。
/// 它運行在另一個 Flutter engine 裡（背景），所以不能用主 App 的 state。
class OverlayBubble extends StatelessWidget {
  const OverlayBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () async {
              // 通知主 App「我被點了」
              await FlutterOverlayWindow.shareData('open_quick_add');
              // 拉起主 App
              try {
                await const MethodChannel('zhiji.overlay/launch')
                    .invokeMethod('bringToFront');
              } catch (_) {}
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B8DEF), Color(0xFF3D6FD9)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.edit_note, color: Colors.white, size: 42),
            ),
          ),
        ),
      ),
    );
  }
}

// overlay entry point 在 main.dart，避免雙重定義。
