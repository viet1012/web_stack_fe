import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'theme/dash_theme.dart';
import 'widgets/theme_reveal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  // Không chờ: font về thì chữ tự vẽ lại.
  loadComicFont();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeReveal(
      builder: (context, mode, instant) => MaterialApp(
        title: 'Dev Manager',
        debugShowCheckedModeBanner: false,
        theme: buildDashTheme(Brightness.light),
        darkTheme: buildDashTheme(Brightness.dark),
        themeMode: mode,
        // Đang reveal thì đổi ngay (ảnh cũ che phía trên); còn lại lerp màu.
        themeAnimationDuration: instant ? Duration.zero : Motion.normal,
        themeAnimationCurve: Motion.curve,
        home: const Dashboard(),
      ),
    );
  }
}
