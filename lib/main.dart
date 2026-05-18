import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/background.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW');
  await NotificationService.instance.init();
  try {
    await BackgroundService.init();
  } catch (_) {}
  runApp(const ZhijiApp());
}

class ZhijiApp extends StatelessWidget {
  const ZhijiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B8DEF);
    return MaterialApp(
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
    );
  }
}
