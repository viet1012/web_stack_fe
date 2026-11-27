import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// COLOR TOKENS (light + dark)
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

  /// Chữ phụ đậm hơn muted (nav item chưa chọn).
  final Color textSoft;

  /// Xám nhạt: nhãn section, viền focus, chấm "not checked".
  final Color faint;

  /// Host/URL mono trên card.
  final Color hostText;

  /// Nền nút chính (Open hover, segmented đang chọn) + chữ trên nó.
  final Color ink;
  final Color onInk;

  /// Nền nav item đang chọn (vàng nhạt).
  final Color navActive;

  /// Màu nhấn thương hiệu của chủ đề (nav/rail đang chọn, viền tour, chấm
  /// chủ đề) + chữ trên nó.
  final Color brand;
  final Color onBrand;

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
    required this.textSoft,
    required this.faint,
    required this.hostText,
    required this.ink,
    required this.onInk,
    required this.navActive,
    required this.brand,
    required this.onBrand,
  });

  /// Sinh bảng màu từ 1 sắc độ trung tính ([hue], [tint] = độ ám màu) và
  /// 1 màu nhấn ([brand]). Nền/viền/chữ chỉ ám rất nhẹ → sạch; màu nhấn chỉ
  /// xuất hiện ở nút chính (tông đậm), mục đang chọn và vài điểm nhỏ.
  factory DashColors.tinted({
    required Brightness brightness,
    required double hue,
    required Color brand,
    double tint = 1,
  }) {
    Color n(double s, double l) =>
        HSLColor.fromAHSL(1, hue, (s * tint).clamp(0.0, 1.0), l).toColor();
    final b = HSLColor.fromColor(brand);
    Color onOf(Color x) =>
        x.computeLuminance() > .42 ? const Color(0xFF111827) : Colors.white;

    if (brightness == Brightness.light) {
      final surface = n(.40, .995);
      // Nút chính = tông rất đậm của màu nhấn (thay đen thuần) → sang hơn.
      final ink = b.withSaturation(b.saturation.clamp(0.0, .62)).withLightness(.25).toColor();
      return DashColors(
        bg: n(.24, .966),
        surface: surface,
        surface2: n(.22, .947),
        border: n(.16, .885),
        text: n(.32, .13),
        muted: n(.11, .42),
        accent: ink,
        cyan: brand,
        ok: DashColors.light.ok,
        bad: DashColors.light.bad,
        warn: DashColors.light.warn,
        shadow: n(.30, .12).withValues(alpha: .08),
        textSoft: n(.14, .32),
        faint: n(.08, .64),
        hostText: n(.11, .42),
        ink: ink,
        onInk: Colors.white,
        navActive: Color.alphaBlend(brand.withValues(alpha: .12), surface),
        brand: brand,
        onBrand: onOf(brand),
      );
    }

    // Dark: màu nhấn sáng lên cho đủ tương phản trên nền tối.
    final lit = b
        .withSaturation(b.saturation.clamp(0.0, .78))
        .withLightness(b.lightness < .64 ? .64 : b.lightness)
        .toColor();
    final bg = n(.22, .062);
    final ink = b.withSaturation(b.saturation.clamp(0.0, .55)).withLightness(.88).toColor();
    return DashColors(
      bg: bg,
      surface: n(.17, .098),
      surface2: n(.15, .136),
      border: n(.13, .19),
      text: n(.18, .92),
      muted: n(.09, .65),
      accent: ink,
      cyan: lit,
      ok: DashColors.dark.ok,
      bad: DashColors.dark.bad,
      warn: DashColors.dark.warn,
      shadow: const Color(0x66000000),
      textSoft: n(.11, .80),
      faint: n(.07, .45),
      hostText: n(.08, .60),
      ink: ink,
      onInk: bg,
      navActive: lit.withValues(alpha: .17),
      brand: lit,
      onBrand: onOf(lit),
    );
  }

  static const light = DashColors(
    bg: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6472),
    accent: Color(0xFF111827),
    cyan: Color(0xFF0891B2),
    ok: Color(0xFF15803D),
    bad: Color(0xFFB91C1C),
    warn: Color(0xFFB45309),
    shadow: Color(0x14111827),
    textSoft: Color(0xFF4B5563),
    faint: Color(0xFF9CA3AF),
    hostText: Color(0xFF5B6472),
    ink: Color(0xFF111827),
    onInk: Color(0xFFFFFFFF),
    navActive: Color(0xFFFFF4D6),
    brand: Brand.yellow,
    onBrand: Color(0xFF111827),
  );

  /// Dark trung tính (graphite), không ám xanh navy; card sáng hơn nền 1 bậc.
  static const dark = DashColors(
    bg: Color(0xFF0D1015),
    surface: Color(0xFF161A21),
    surface2: Color(0xFF1F242D),
    border: Color(0xFF2A303A),
    text: Color(0xFFE8EAEE),
    muted: Color(0xFF9AA3B1),
    accent: Color(0xFFE8EAEE),
    cyan: Color(0xFF22D3EE),
    ok: Color(0xFF4ADE80),
    bad: Color(0xFFF87171),
    warn: Color(0xFFFBBF24),
    shadow: Color(0x66000000),
    textSoft: Color(0xFFC3C9D3),
    faint: Color(0xFF6B7380),
    hostText: Color(0xFF8F99A8),
    ink: Color(0xFFE8EAEE),
    onInk: Color(0xFF0D1015),
    navActive: Color(0x29FFC93C),
    brand: Brand.yellow,
    onBrand: Color(0xFF111827),
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
        textSoft: textSoft,
        faint: faint,
        hostText: hostText,
        ink: ink,
        onInk: onInk,
        navActive: navActive,
        brand: brand,
        onBrand: onBrand,
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
      textSoft: l(textSoft, other.textSoft),
      faint: l(faint, other.faint),
      hostText: l(hostText, other.hostText),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      navActive: l(navActive, other.navActive),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
    );
  }
}

// ============================================================
// STATUS TONES (chip / chấm / banner trạng thái)
// ============================================================

/// Ngưỡng "Slow".
const int kSlowMs = 100;

@immutable
class StatusTone extends ThemeExtension<StatusTone> {
  final Color okFg, okBg;
  final Color slowFg, slowBg;
  final Color offFg, offBg, offBorder;
  final Color bannerBg, bannerText;
  final Color idleFg, idleBg;

  /// Chấm tổng ở header.
  final Color dotOk, dotBad;

  const StatusTone({
    required this.okFg,
    required this.okBg,
    required this.slowFg,
    required this.slowBg,
    required this.offFg,
    required this.offBg,
    required this.offBorder,
    required this.bannerBg,
    required this.bannerText,
    required this.idleFg,
    required this.idleBg,
    required this.dotOk,
    required this.dotBad,
  });

  static const light = StatusTone(
    okFg: Color(0xFF15803D),
    okBg: Color(0xFFE9F7EE),
    slowFg: Color(0xFFB45309),
    slowBg: Color(0xFFFEF3E2),
    offFg: Color(0xFFB91C1C),
    offBg: Color(0xFFFEECEC),
    offBorder: Color(0xFFF5C2C2),
    bannerBg: Color(0xFFFEF2F2),
    bannerText: Color(0xFF7F1D1D),
    idleFg: Color(0xFF5B6472),
    idleBg: Color(0xFFF3F4F6),
    dotOk: Color(0xFF16A34A),
    dotBad: Color(0xFFDC2626),
  );

  /// Dark: chữ sáng hơn, nền chip = màu chữ ~12% alpha.
  static const dark = StatusTone(
    okFg: Color(0xFF4ADE80),
    okBg: Color(0x1F4ADE80),
    slowFg: Color(0xFFFBBF24),
    slowBg: Color(0x1FFBBF24),
    offFg: Color(0xFFF87171),
    offBg: Color(0x24F87171),
    offBorder: Color(0x66F87171),
    bannerBg: Color(0x17F87171),
    bannerText: Color(0xFFFCA5A5),
    idleFg: Color(0xFF9AA3B1),
    idleBg: Color(0xFF1F242D),
    dotOk: Color(0xFF22C55E),
    dotBad: Color(0xFFEF4444),
  );

  @override
  StatusTone copyWith() => this;

  @override
  StatusTone lerp(StatusTone? o, double t) {
    if (o == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StatusTone(
      okFg: l(okFg, o.okFg),
      okBg: l(okBg, o.okBg),
      slowFg: l(slowFg, o.slowFg),
      slowBg: l(slowBg, o.slowBg),
      offFg: l(offFg, o.offFg),
      offBg: l(offBg, o.offBg),
      offBorder: l(offBorder, o.offBorder),
      bannerBg: l(bannerBg, o.bannerBg),
      bannerText: l(bannerText, o.bannerText),
      idleFg: l(idleFg, o.idleFg),
      idleBg: l(idleBg, o.idleBg),
      dotOk: l(dotOk, o.dotOk),
      dotBad: l(dotBad, o.dotBad),
    );
  }
}

extension DashContext on BuildContext {
  DashColors get dash => Theme.of(this).extension<DashColors>()!;
  StatusTone get tone => Theme.of(this).extension<StatusTone>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Màu phòng ban theo theme hiện tại.
  DeptColor dept(String name) => deptColor(name, Theme.of(this).brightness);
}

// ============================================================
// BRAND / FONTS
// ============================================================

class Brand {
  /// Chỉ dùng cho logo IT PRO và nav item đang chọn.
  static const yellow = Color(0xFFFFC93C);
}

// Cache style gốc theo (size, weight): GoogleFonts.*() mỗi lần gọi đều tra
// font + đăng ký load → gọi hàng trăm lần mỗi lần rebuild sẽ chậm.
final Map<(double, FontWeight), TextStyle> _displayCache = {};
final Map<double, TextStyle> _monoCache = {};

/// Space Grotesk — tiêu đề / số liệu.
TextStyle displayText({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    _displayCache
        .putIfAbsent(
          (size, weight),
          () => GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight),
        )
        .copyWith(color: color, height: height, letterSpacing: letterSpacing);

/// JetBrains Mono — URL / host.
TextStyle monoText({double size = 12, Color? color, double? height}) =>
    _monoCache
        .putIfAbsent(size, () => GoogleFonts.jetBrainsMono(fontSize: size))
        .copyWith(color: color, height: height);

// ============================================================
// DEPARTMENT COLORS (fg / bg)
// ============================================================

@immutable
class DeptColor {
  final Color fg;
  final Color bg;
  const DeptColor(this.fg, this.bg);
}

/// Bảng màu light. Thứ tự cũng là thứ tự sort card.
const Map<String, DeptColor> kDeptColors = {
  'KVH': DeptColor(Color(0xFF1D4ED8), Color(0xFFE8EEFD)),
  'PRO': DeptColor(Color(0xFFC2410C), Color(0xFFFDEEE4)),
  'HR': DeptColor(Color(0xFF7C3AED), Color(0xFFF1EAFE)),
  'IT': DeptColor(Color(0xFF4338CA), Color(0xFFE8E8FB)),
  'MA': DeptColor(Color(0xFF0F766E), Color(0xFFE2F4F1)),
  'PC': DeptColor(Color(0xFF15803D), Color(0xFFE4F4E9)),
  'TE': DeptColor(Color(0xFFBE185D), Color(0xFFFCE7F1)),
  'WH': DeptColor(Color(0xFF475569), Color(0xFFEDF0F4)),
};

/// Dark: chữ = màu gốc sáng lên (đủ tương phản trên nền tối),
/// nền = màu gốc ~18% alpha.
final Map<String, DeptColor> _deptDark = {
  for (final e in kDeptColors.entries)
    e.key: DeptColor(
      Color.lerp(e.value.fg, Colors.white, .42)!,
      e.value.fg.withValues(alpha: .2),
    ),
};

const _deptAlias = {'PRODUCTION': 'PRO', 'WAREHOUSE': 'WH'};

String _deptKey(String name) {
  final k = name.trim().toUpperCase();
  return _deptAlias[k] ?? k;
}

DeptColor deptColor(String name, [Brightness b = Brightness.light]) {
  final map = b == Brightness.dark ? _deptDark : kDeptColors;
  return map[_deptKey(name)] ?? map['WH']!;
}

int deptRank(String name) {
  final i = kDeptColors.keys.toList().indexOf(_deptKey(name));
  return i < 0 ? kDeptColors.length : i;
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

  /// Bật trong đúng frame đổi theme: mọi AnimatedContainer/AnimatedSwitcher
  /// đổi màu NGAY thay vì tự animate 200ms bên dưới tấm rèm (tránh cả trang
  /// repaint liên tục trong lúc rèm đang kéo). Không gây rebuild thêm.
  static bool instant = false;

  static Duration of(BuildContext context, [Duration base = normal]) =>
      instant || reduced(context) ? Duration.zero : base;
}

// ============================================================
// THEME MODE (localStorage qua shared_preferences)
// ============================================================

// ============================================================
// PALETTES (chủ đề màu theo lĩnh vực)
// ============================================================

/// 1 chủ đề màu, có đủ bản Light + Dark.
@immutable
class DashPalette {
  final String id;

  /// Tên chủ đề (vd. "Indigo") + lĩnh vực gợi ý (vd. "IT").
  final String name;
  final String scope;
  final DashColors light;
  final DashColors dark;

  const DashPalette({
    required this.id,
    required this.name,
    required this.scope,
    required this.light,
    required this.dark,
  });

  DashPalette.tinted({
    required this.id,
    required this.name,
    required this.scope,
    required double hue,
    required Color brand,
    double tint = 1,
  }) : light = DashColors.tinted(
         brightness: Brightness.light,
         hue: hue,
         brand: brand,
         tint: tint,
       ),
       dark = DashColors.tinted(
         brightness: Brightness.dark,
         hue: hue,
         brand: brand,
         tint: tint,
       );

  DashColors of(Brightness b) => b == Brightness.dark ? dark : light;

  static const graphite = DashPalette(
    id: 'graphite',
    name: 'Graphite',
    scope: 'Mặc định',
    light: DashColors.light,
    dark: DashColors.dark,
  );

  /// Thứ tự hiển thị trong bảng chọn.
  static final all = <DashPalette>[
    graphite,
    DashPalette.tinted(
      id: 'it',
      name: 'Indigo',
      scope: 'IT',
      hue: 232,
      brand: const Color(0xFF4F46E5),
    ),
    DashPalette.tinted(
      id: 'ma',
      name: 'Teal',
      scope: 'MA',
      hue: 182,
      brand: const Color(0xFF0D9488),
    ),
    DashPalette.tinted(
      id: 'pc',
      name: 'Forest',
      scope: 'PC',
      hue: 150,
      brand: const Color(0xFF059669),
    ),
    DashPalette.tinted(
      id: 'product',
      name: 'Copper',
      scope: 'Product',
      hue: 28,
      tint: .9,
      brand: const Color(0xFFC2410C),
    ),
    DashPalette.tinted(
      id: 'factory',
      name: 'Steel',
      scope: 'Xưởng',
      hue: 205,
      tint: 1.25,
      brand: const Color(0xFF0284C7),
    ),
    DashPalette.tinted(
      id: 'kvh',
      name: 'Navy',
      scope: 'KVH',
      hue: 222,
      brand: const Color(0xFF1D4ED8),
    ),
    DashPalette.tinted(
      id: 'hr',
      name: 'Plum',
      scope: 'HR',
      hue: 275,
      tint: .85,
      brand: const Color(0xFF7C3AED),
    ),
    DashPalette.tinted(
      id: 'te',
      name: 'Rose',
      scope: 'TE',
      hue: 340,
      tint: .8,
      brand: const Color(0xFFBE185D),
    ),
    DashPalette.tinted(
      id: 'classic',
      name: 'Bronze',
      scope: 'Văn phòng',
      hue: 38,
      tint: .8,
      brand: const Color(0xFFA16207),
    ),
  ];

  static DashPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => graphite);
}

/// Mặc định theo hệ điều hành; người dùng bấm đổi → nhớ lựa chọn.
class ThemeController {
  static const _key = 'dash.themeMode';
  static const _paletteKey = 'dash.palette';

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final palette = ValueNotifier<DashPalette>(DashPalette.graphite);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      palette.value = DashPalette.byId(prefs.getString(_paletteKey));
    } catch (_) {}
  }

  /// Đổi chủ đề màu. Màu đổi tức thì trong đúng frame đó (không để hàng
  /// trăm AnimatedContainer tự animate → đỡ giật).
  static Future<void> setPalette(DashPalette p) async {
    if (palette.value.id == p.id) return;
    Motion.instant = true;
    palette.value = p;
    await WidgetsBinding.instance.endOfFrame;
    Motion.instant = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_paletteKey, p.id);
    } catch (_) {}
  }

  /// Đổi sang theme ngược với theme đang hiển thị ([current]).
  static Future<void> toggle(Brightness current) async {
    mode.value =
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        mode.value == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {}
  }
}

ThemeData buildDashTheme(
  Brightness brightness, [
  DashPalette palette = DashPalette.graphite,
]) {
  final dark = brightness == Brightness.dark;
  final c = palette.of(brightness);
  final tone = dark ? StatusTone.dark : StatusTone.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: GoogleFonts.inter().fontFamily,
    fontFamilyFallback: const ['system-ui', 'Segoe UI', 'Roboto', 'Arial'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D4ED8),
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onInk,
      surface: c.surface,
      error: c.bad,
      onSurface: c.text,
      outline: c.border,
    ),
    extensions: [c, tone],
    dividerColor: c.border,
    focusColor: c.text.withValues(alpha: .12),
    hoverColor: c.surface2,
    splashColor: c.text.withValues(alpha: .06),
    highlightColor: c.text.withValues(alpha: .04),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.text,
      selectionColor: palette == DashPalette.graphite
          ? const Color(0xFF3B82F6).withValues(alpha: .3)
          : c.brand.withValues(alpha: .28),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.faint.withValues(alpha: .5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: TextStyle(color: dark ? c.text : Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: dark ? c.border : c.text,
        borderRadius: BorderRadius.circular(6),
        border: dark
            ? Border.all(color: Color.lerp(c.border, c.text, .1)!)
            : null,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.onInk, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
