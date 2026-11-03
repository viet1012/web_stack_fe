import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// COLOR TOKENS (dark default + light)
// ============================================================

@immutable
class DashColors extends ThemeExtension<DashColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color cyan;
  final Color ok;
  final Color bad;
  final Color warn;

  /// Màu chữ/icon đặt trên nền [accent].
  final Color onAccent;

  /// Mực truyện tranh: viền + bóng in lệch.
  final Color ink;

  /// Vàng "anh hùng" cho nút đang chọn, tiêu đề.
  final Color hero;

  /// Vòng sáng quanh khung ở dark mode (viền mực không thấy trên nền tối).
  final Color ring;

  const DashColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.cyan,
    required this.ok,
    required this.bad,
    required this.warn,
    required this.onAccent,
    required this.ink,
    required this.hero,
    required this.ring,
  });

  static const dark = DashColors(
    bg: Color(0xFF120E2E),
    surface: Color(0xFF1E1846),
    surface2: Color(0xFF2A2360),
    border: Color(0xFF3B3380),
    text: Color(0xFFF4F1FF),
    muted: Color(0xFFB3AAD9),
    accent: Color(0xFFFFD23F),
    cyan: Color(0xFF2FD3E0),
    ok: Color(0xFF3DDC84),
    bad: Color(0xFFFF4D6D),
    warn: Color(0xFFFFB020),
    onAccent: Color(0xFF14121F),
    ink: Color(0xFF14121F),
    hero: Color(0xFFFFD23F),
    ring: Color(0xCCFFFFFF),
  );

  static const light = DashColors(
    bg: Color(0xFFFFF3CC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFF8E1),
    border: Color(0xFFD9CDA4),
    text: Color(0xFF14121F),
    muted: Color(0xFF5E5878),
    accent: Color(0xFF6C4CF0),
    cyan: Color(0xFF0E9AA7),
    ok: Color(0xFF1F9D55),
    bad: Color(0xFFE8384F),
    warn: Color(0xFFD98A00),
    onAccent: Color(0xFFFFFFFF),
    ink: Color(0xFF14121F),
    hero: Color(0xFFFFD23F),
    ring: Color(0x00FFFFFF),
  );

  @override
  DashColors copyWith({Color? accent}) => DashColors(
        bg: bg,
        surface: surface,
        surface2: surface2,
        border: border,
        text: text,
        muted: muted,
        accent: accent ?? this.accent,
        cyan: cyan,
        ok: ok,
        bad: bad,
        warn: warn,
        onAccent: onAccent,
        ink: ink,
        hero: hero,
        ring: ring,
      );

  @override
  DashColors lerp(DashColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DashColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      border: l(border, other.border),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      cyan: l(cyan, other.cyan),
      ok: l(ok, other.ok),
      bad: l(bad, other.bad),
      warn: l(warn, other.warn),
      onAccent: l(onAccent, other.onAccent),
      ink: l(ink, other.ink),
      hero: l(hero, other.hero),
      ring: l(ring, other.ring),
    );
  }
}

extension DashContext on BuildContext {
  DashColors get dash => Theme.of(this).extension<DashColors>()!;
}

// ============================================================
// COMIC STYLE: viền mực + bóng in lệch, font Bangers
// ============================================================

const kComicFont = 'Bangers';

// Bangers (SIL OFL) tải lúc chạy; lỗi mạng → chữ dùng font dự phòng.
const _comicFontUrl =
    'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/bangers/Bangers-Regular.ttf';

Future<void> loadComicFont() async {
  try {
    final res = await http.get(Uri.parse(_comicFontUrl));
    if (res.statusCode != 200) return;
    await (FontLoader(kComicFont)
          ..addFont(Future.value(ByteData.sublistView(res.bodyBytes))))
        .load();
  } catch (_) {}
}

/// Bóng in lệch cứng (không blur) + vòng sáng ở dark mode.
List<BoxShadow> comicShadows(DashColors c, [double offset = 5]) {
  final ringed = c.ring.a > 0;
  return [
    BoxShadow(
      color: c.ink,
      offset: Offset(offset, offset),
      spreadRadius: ringed ? 2 : 0,
    ),
    if (ringed) BoxShadow(color: c.ring, spreadRadius: 2),
  ];
}

BoxDecoration comicPanel(
  DashColors c, {
  Color? color,
  double radius = 12,
  double border = 2.5,
  double offset = 5,
}) =>
    BoxDecoration(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.ink, width: border),
      boxShadow: comicShadows(c, offset),
    );

// ============================================================
// TAG COLORS
// ============================================================

const Map<String, Color> _tagColors = {
  'document': Color(0xFF38BDF8),
  'hr': Color(0xFFF472B6),
  'heat guide': Color(0xFFFB923C),
  'heat press': Color(0xFFE879F9),
  'molybden': Color(0xFFA78BFA),
  'printer': Color(0xFF2DD4BF),
  'production': Color(0xFF84CC16),
  'report': Color(0xFFFBBF24),
};

const List<Color> _fallbackTagColors = [
  Color(0xFF60A5FA),
  Color(0xFF34D399),
  Color(0xFFF97316),
  Color(0xFFC084FC),
];

Color tagColor(String tag) {
  final key = tag.trim().toLowerCase();
  return _tagColors[key] ??
      _fallbackTagColors[key.hashCode.abs() % _fallbackTagColors.length];
}

// ============================================================
// MOTION
// ============================================================

class Motion {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 240);
  static const curve = Cubic(.2, .8, .2, 1);

  static final bool _prefersReduced =
      html.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  static bool reduced(BuildContext context) =>
      _prefersReduced || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static Duration of(BuildContext context, [Duration base = normal]) =>
      reduced(context) ? Duration.zero : base;
}

// ============================================================
// THEME MODE (saved in localStorage via shared_preferences)
// ============================================================

class ThemeController {
  static const _key = 'dash.themeMode';

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value =
          prefs.getString(_key) == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    mode.value =
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        mode.value == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {}
  }
}

ThemeData buildDashTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? DashColors.dark : DashColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['system-ui', 'Segoe UI', 'Roboto', 'Arial'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      error: c.bad,
      onSurface: c.text,
    ),
    extensions: [c],
    dividerColor: c.border,
    focusColor: c.accent.withValues(alpha: .18),
    hoverColor: c.surface2,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: TextStyle(color: c.bg, fontSize: 12),
      decoration: BoxDecoration(
        color: c.text,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: TextStyle(color: c.bg, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
