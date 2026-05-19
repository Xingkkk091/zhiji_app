import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 控制懸浮球的開關與接收 overlay 點擊事件。
class OverlayService {
  /// 主 App 端：開啟懸浮球
  /// 回傳值：null = 成功，非 null = 錯誤訊息
  static Future<String?> showBubble() async {
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        final granted = await FlutterOverlayWindow.requestPermission();
        if (granted != true) {
          // 再 check 一次 (有些手機 requestPermission 不會等到 user 真正開)
          if (!await FlutterOverlayWindow.isPermissionGranted()) {
            return '尚未授權「在其他 App 上層顯示」，請手動到系統設定開啟';
          }
        }
      }
      if (await FlutterOverlayWindow.isActive()) return null;

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
      // 等系統把 overlay 建起來
      await Future.delayed(const Duration(milliseconds: 400));
      if (!await FlutterOverlayWindow.isActive()) {
        return '已呼叫顯示，但系統未啟用 overlay (可能被省電/權限阻擋)';
      }
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
