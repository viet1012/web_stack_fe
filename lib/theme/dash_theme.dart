import 'dart:html' as html;

import 'package:flutter/material.dart';
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
  final Color shadow;

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
    required this.shadow,
  });

  static const dark = DashColors(
    bg: Color(0xFF0A0F1C),
    surface: Color(0xFF111A2B),
    surface2: Color(0xFF172238),
    border: Color(0xFF1F2A40),
    text: Color(0xFFE6EBF5),
    muted: Color(0xFF8A96AD),
    accent: Color(0xFF4F8CFF),
    cyan: Color(0xFF22D3EE),
    ok: Color(0xFF22C55E),
    bad: Color(0xFFF43F5E),
    warn: Color(0xFFF59E0B),
    shadow: Color(0x99000000),
  );

  static const light = DashColors(
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF1F7),
    border: Color(0xFFDCE2EC),
    text: Color(0xFF0F172A),
    muted: Color(0xFF5B6780),
    accent: Color(0xFF2F6FED),
    cyan: Color(0xFF0891B2),
    ok: Color(0xFF16A34A),
    bad: Color(0xFFE11D48),
    warn: Color(0xFFD97706),
    shadow: Color(0x22101828),
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
        shadow: shadow,
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
      shadow: l(shadow, other.shadow),
    );
  }
}

extension DashContext on BuildContext {
  DashColors get dash => Theme.of(this).extension<DashColors>()!;
}

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
