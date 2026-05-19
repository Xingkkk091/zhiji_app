import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/quick_add_screen.dart';
import 'services/foreground_service.dart';
import 'services/notifications.dart';
import 'services/overlay_service.dart';

/// overlay 端 isolate 進入點
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayBubble());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW');
  await NotificationService.instance.init();
  await ForegroundService.init();
  runApp(const ZhijiApp());
}

class ZhijiApp extends StatefulWidget {
  const ZhijiApp({super.key});
  @override
  State<ZhijiApp> createState() => _ZhijiAppState();
}

class _ZhijiAppState extends State<ZhijiApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 監聽懸浮球的訊息
    OverlayService.overlayMessages().listen((data) {
      if (data == 'open_quick_add') {
        _navKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const QuickAddScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B8DEF);
    return WithForegroundTask(
      child: MaterialApp(
        navigatorKey: _navKey,
        title: '智記',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
