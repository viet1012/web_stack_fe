import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'screens/dashboard.dart';
import 'theme/dash_theme.dart';
import 'widgets/theme_curtain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DEBUG: in đầy đủ MỌI lỗi (kèm "The relevant error-causing widget was:
  // file:line") thay vì "Another exception was thrown" rút gọn.
  // Xoá khối này khi đã sửa xong overflow.
  if (kDebugMode) {
    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details, forceReport: true);
  }
  // Tải trước mọi weight đang dùng → không bị nhảy chữ / giật khi lần đầu
  // đổi mục (mỗi weight Google Fonts tải riêng). Tối đa 2s rồi vẫn chạy app.
  try {
    await GoogleFonts.pendingFonts([
      for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700])
        GoogleFonts.inter(fontWeight: w),
      for (final w in [FontWeight.w500, FontWeight.w600, FontWeight.w700])
        GoogleFonts.spaceGrotesk(fontWeight: w),
      GoogleFonts.jetBrainsMono(),
    ]).timeout(const Duration(seconds: 2));
  } catch (_) {}

  // Debug web (DDC) nạp thư viện lucide_icons (hàng nghìn icon) ở lần đọc
  // non-const ĐẦU TIÊN. Nếu lần đó nằm sâu trong cây widget → Stack Overflow.
  // Đọc 1 icon ở đây (stack còn nông) để thư viện được khởi tạo sẵn.
  debugPrint('icons ready: ${LucideIcons.x.codePoint}');

  await ThemeController.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _light = buildDashTheme(Brightness.light);
  static final _dark = buildDashTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'IT PRO', // tiêu đề tab trình duyệt
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        themeMode: mode,
        // Đổi theme tức thì. Animate (lerp ThemeData) bắt toàn bộ cây
        // rebuild + layout mỗi frame trong suốt animation → giật.
        themeAnimationDuration: Duration.zero,
        // Hiệu ứng rèm cửa khi đổi theme (che frame rebuild nặng).
        builder: (context, child) => ThemeCurtain(child: child!),
        home: const Dashboard(),
      ),
    );
  }
}
