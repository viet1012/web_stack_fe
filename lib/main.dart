import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'theme/dash_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Dev Manager',
        debugShowCheckedModeBanner: false,
        theme: buildDashTheme(Brightness.light),
        darkTheme: buildDashTheme(Brightness.dark),
        themeMode: mode,
        themeAnimationDuration: Motion.normal,
        themeAnimationCurve: Motion.curve,
        home: const Dashboard(),
      ),
    );
  }
}
