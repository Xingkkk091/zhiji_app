import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 控制懸浮球的開關與接收 overlay 點擊事件。
class OverlayService {
  /// 主 App 端：開啟懸浮球
  static Future<bool> showBubble() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      final granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) return false;
    }
    if (await FlutterOverlayWindow.isActive()) return true;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: '智記',
      overlayContent: '點我快速記事',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 140,
      width: 140,
      alignment: OverlayAlignment.centerRight,
    );
    return true;
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B8DEF), Color(0xFF3D6FD9)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B8DEF).withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.edit_note, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

/// overlay entry point — 必須是頂層函式
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayBubble());
}
