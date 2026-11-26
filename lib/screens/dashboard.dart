import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../models/website.dart';
import '../services/screenshot_store.dart';
import '../services/status_store.dart';
import '../services/visit_store.dart';
import '../services/website_service.dart';
import '../theme/dash_theme.dart';
import '../widgets/dash_ui.dart';
import '../widgets/onboarding_tour.dart';
import '../widgets/preview_dialog.dart';
import '../widgets/sidebar.dart';
import '../widgets/site_thumbnail.dart' show Shimmer;
import '../widgets/team_art.dart' show DeptHealth;
import '../widgets/theme_curtain.dart';
import '../widgets/website_card.dart';

enum StatusFilter { all, online, offline }

/// Neo các vùng được giới thiệu trong hướng dẫn người mới (OnboardingTour).
class _TourKeys {
  final sidebar = GlobalKey(debugLabel: 'tour.sidebar');
  final status = GlobalKey(debugLabel: 'tour.status');
  final search = GlobalKey(debugLabel: 'tour.search');
  final filter = GlobalKey(debugLabel: 'tour.filter');
  final preview = GlobalKey(debugLabel: 'tour.preview');
  final theme = GlobalKey(debugLabel: 'tour.theme');
  final refresh = GlobalKey(debugLabel: 'tour.refresh');
  final help = GlobalKey(debugLabel: 'tour.help');
  final frequent = GlobalKey(debugLabel: 'tour.frequent');
  final card = GlobalKey(debugLabel: 'tour.card');
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // DATA
  // ============================================================

  List<Website> all = [];
  int _listVersion = 0;
  final StatusStore store = StatusStore();
  final ScreenshotStore shots = ScreenshotStore();
  final VisitStore visits = VisitStore()..load();

  String selectedDepartment = kAllDept;
  StatusFilter statusFilter = StatusFilter.all;
  String query = '';

  /// Sidebar thu gọn (màn rộng), nhớ trong localStorage.
  static const _collapsedKey = 'itpro.sidebarCollapsed';
  bool _sidebarCollapsed = () {
    try {
      return html.window.localStorage[_collapsedKey] == '1';
    } catch (_) {
      return false;
    }
  }();

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    try {
      html.window.localStorage[_collapsedKey] = _sidebarCollapsed ? '1' : '0';
    } catch (_) {}
  }

  /// Ẩn/hiện ảnh preview của TẤT CẢ card (mặc định hiện), nhớ trong localStorage.
  static const _previewKey = 'itpro.showPreview';
  bool _showPreview = () {
    try {
      return html.window.localStorage[_previewKey] != '0';
    } catch (_) {
      return true;
    }
  }();

  /// Thứ tự kéo-thả của Frequently visited (danh sách id), lưu localStorage.
  static const _favOrderKey = 'itpro.favOrder';
  List<int> _favOrder = () {
    try {
      final raw = html.window.localStorage[_favOrderKey];
      if (raw == null || raw.isEmpty) return <int>[];
      return (jsonDecode(raw) as List)
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
    } catch (_) {
      return <int>[];
    }
  }();

  /// Site được gắn sao (ghim lên Frequently visited), lưu localStorage.
  /// Không hết hạn — chỉ mất khi bỏ sao hoặc xoá dữ liệu trình duyệt.
  static const _starKey = 'itpro.starred';
  final Set<int> _starred = () {
    try {
      final raw = html.window.localStorage[_starKey];
      if (raw == null || raw.isEmpty) return <int>{};
      return (jsonDecode(raw) as List)
          .whereType<num>()
          .map((e) => e.toInt())
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }();

  void _toggleStar(Website w) {
    setState(() {
      if (!_starred.remove(w.id)) _starred.add(w.id);
    });
    try {
      html.window.localStorage[_starKey] = jsonEncode(_starred.toList());
    } catch (_) {}
  }

  /// Nút X ở Frequently visited: bỏ sao (nếu có) + xoá lượt mở của site →
  /// site biến mất khỏi khung, chỉ quay lại khi gắn sao hoặc mở lại nhiều.
  void _removeFav(Website w) {
    setState(() {
      _starred.remove(w.id);
      _favOrder.remove(w.id);
    });
    try {
      html.window.localStorage[_starKey] = jsonEncode(_starred.toList());
      html.window.localStorage[_favOrderKey] = jsonEncode(_favOrder);
    } catch (_) {}
    visits.forget(w.id);
  }

  /// Sắp [items] (đã theo số lượt mở) theo thứ tự người dùng kéo thả.
  /// Site chưa từng được kéo → đứng sau, giữ thứ tự theo lượt mở.
  List<Website> _applyFavOrder(List<Website> items) {
    int rank(Website w) {
      final i = _favOrder.indexOf(w.id);
      return i < 0 ? 1 << 20 : i;
    }

    final base = {for (var i = 0; i < items.length; i++) items[i].id: i};
    return [...items]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : base[a.id]!.compareTo(base[b.id]!);
    });
  }

  /// Thả [dragId] vào vị trí của [targetId] trong danh sách đang hiển thị.
  void _moveFav(List<Website> shown, int dragId, int targetId) {
    if (dragId == targetId) return;
    final ids = shown.map((w) => w.id).toList();
    final from = ids.indexOf(dragId);
    final to = ids.indexOf(targetId);
    if (from < 0 || to < 0) return;
    ids.removeAt(from);
    // Kéo sang phải → chèn SAU ô đích; kéo sang trái → chèn TRƯỚC ô đích.
    ids.insert(
      from < to ? ids.indexOf(targetId) + 1 : ids.indexOf(targetId),
      dragId,
    );

    setState(() {
      _favOrder = [...ids, ..._favOrder.where((id) => !ids.contains(id))];
    });
    try {
      html.window.localStorage[_favOrderKey] = jsonEncode(_favOrder);
    } catch (_) {}
  }

  void _togglePreviewAll() {
    setState(() => _showPreview = !_showPreview);
    try {
      html.window.localStorage[_previewKey] = _showPreview ? '1' : '0';
    } catch (_) {}
  }

  // ============================================================
  // ONBOARDING TOUR
  // ============================================================

  final _tk = _TourKeys();
  bool _touring = false;

  Future<void> _startTour() async {
    if (!mounted || _touring) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final narrow = MediaQuery.sizeOf(context).width < 900;
    _touring = true;
    try {
      await OnboardingTour.show(context, [
        const TourStep(
          icon: LucideIcons.sparkles,
          title: 'Chào mừng đến IT PRO',
          body:
              'Website Dashboard tập hợp toàn bộ website nội bộ của các phòng '
              'ban và tự kiểm tra site nào đang online / offline.\n'
              'Hướng dẫn nhanh này giới thiệu các nút chức năng (khoảng 1 phút). '
              'Dùng phím ← → để chuyển bước, Esc để thoát.',
        ),
        TourStep(
          target: _tk.sidebar,
          icon: LucideIcons.layoutGrid,
          title: 'Phòng ban',
          body:
              'Bấm vào tên 1 phòng ban để chỉ xem website của phòng đó. '
              'Bấm "All sites" để xem lại tất cả.',
          example: _DeptExample(
            mode: narrow
                ? _DeptExampleMode.chip
                : (_sidebarCollapsed
                      ? _DeptExampleMode.rail
                      : _DeptExampleMode.row),
          ),
          items: [
            if (narrow || !_sidebarCollapsed) ...[
              (
                LucideIcons.wifiOff,
                'Nhãn ĐỎ (biểu tượng wifi gạch chéo + số): số website của '
                    'phòng đang KHÔNG truy cập được. Ví dụ trên: phòng KVH có '
                    '2 site đang lỗi.',
              ),
              (
                LucideIcons.hash,
                'Số XÁM: tổng số website của phòng (ví dụ trên: 5 site).',
              ),
            ] else
              (
                LucideIcons.wifiOff,
                'Số ĐỎ ở góc ô: số website của phòng đang KHÔNG truy cập được. '
                    'Di chuột lên ô để xem tên phòng và số site.',
              ),
            (
              LucideIcons.circleCheck,
              'Không có nhãn đỏ = mọi site của phòng đều hoạt động bình thường.',
            ),
            if (!narrow)
              (
                _sidebarCollapsed
                    ? LucideIcons.panelLeftOpen
                    : LucideIcons.panelLeftClose,
                'Nút thu gọn / mở rộng thanh bên — phím tắt '
                    '${Sidebar.shortcutLabel}',
              ),
          ],
        ),
        TourStep(
          target: _tk.status,
          icon: LucideIcons.activity,
          title: 'Tình trạng chung',
          body:
              'Cho biết nhanh hệ thống đang ổn hay không. Di chuột lên dòng '
              'này để xem giải thích chi tiết.',
          items: const [
            (
              LucideIcons.circleCheck,
              '21/24 online: 21 trên tổng 24 site đang truy cập được',
            ),
            (
              LucideIcons.gauge,
              'Phản hồi ~180 ms: thời gian một site thường mất để trả lời. '
                  'Càng nhỏ càng nhanh (1000 ms = 1 giây)',
            ),
            (
              LucideIcons.clock,
              'Cập nhật lúc …: lần kiểm tra gần nhất. Trang tự kiểm tra lại '
                  'mỗi 60 giây',
            ),
          ],
        ),
        TourStep(
          target: _tk.search,
          icon: LucideIcons.search,
          title: 'Tìm kiếm',
          body: 'Tìm theo tên, URL hoặc tên phòng ban.',
          items: const [
            (
              LucideIcons.keyboard,
              'Nhấn / ở bất kỳ đâu để nhảy vào ô tìm kiếm',
            ),
            (LucideIcons.x, 'Esc để xoá nội dung tìm kiếm'),
          ],
        ),
        TourStep(
          target: _tk.filter,
          icon: LucideIcons.listFilter,
          title: 'Lọc theo trạng thái',
          body:
              'All / Online / Offline. Con số bên cạnh là số site khớp phòng '
              'ban và từ khoá đang chọn.',
        ),
        TourStep(
          target: _tk.preview,
          icon: LucideIcons.image,
          title: 'Ẩn / hiện ảnh xem trước',
          body:
              'Bật/tắt ảnh chụp màn hình trên tất cả thẻ website. Tắt đi để '
              'danh sách gọn hơn. Lựa chọn được ghi nhớ.',
        ),
        TourStep(
          target: _tk.theme,
          icon: LucideIcons.sunMoon,
          title: 'Giao diện Sáng / Tối',
          body: 'Chuyển giữa Light và Dark. Lựa chọn được ghi nhớ cho lần sau.',
        ),
        TourStep(
          target: _tk.refresh,
          icon: LucideIcons.refreshCw,
          title: 'Làm mới',
          body:
              'Chụp lại ảnh và kiểm tra lại toàn bộ site ngay. Sau khi bấm, nút '
              'tạm khoá 10 giây để tránh bấm liên tục.',
        ),
        TourStep(
          target: _tk.frequent,
          icon: LucideIcons.star,
          title: 'Frequently visited',
          body:
              'Site đã gắn sao (luôn hiện) + site bạn mở nhiều nhất trong 30 '
              'ngày gần đây.',
          items: const [
            (LucideIcons.grab, 'Kéo thả thẻ để đổi thứ tự'),
            (LucideIcons.x, 'Gỡ site khỏi khung này'),
          ],
        ),
        TourStep(
          target: _tk.card,
          icon: LucideIcons.panelsTopLeft,
          title: 'Thẻ website',
          body:
              'Chấm màu cạnh tên cho biết trạng thái: xanh = online, cam = chậm '
              '/ cần đăng nhập / đang kiểm tra, đỏ = offline, xám = chưa kiểm tra. '
              'Di chuột lên chấm để xem chi tiết.',
          items: const [
            (LucideIcons.star, 'Gắn sao để ghim site lên Frequently visited'),
            (LucideIcons.externalLink, 'Mở site trong tab mới'),
            (LucideIcons.copy, 'Sao chép địa chỉ URL'),
            (
              LucideIcons.mousePointerClick,
              'Bấm vào ảnh xem trước cũng mở site. Ảnh trống → nút "Open live" '
                  'để xem trực tiếp',
            ),
          ],
        ),
        TourStep(
          target: _tk.help,
          icon: LucideIcons.circleHelp,
          title: 'Xem lại hướng dẫn',
          body:
              'Bấm nút này (hoặc phím ?) bất cứ lúc nào để xem lại hướng dẫn.',
        ),
      ]);
    } finally {
      _touring = false;
    }
  }

  bool loading = true;
  String? loadError;

  /// Stagger fade-in chỉ chạy 1 lần lúc load đầu.
  bool _stagger = true;

  // ============================================================
  // REFRESH
  // ============================================================

  static const Duration _refreshInterval = Duration(seconds: 60);
  Timer? _refreshTimer;
  bool _fetching = false;
  StreamSubscription<html.Event>? _visibilitySub;

  /// Sau khi bấm Refresh: khóa nút 10s (tránh spam chụp lại).
  static const Duration _refreshCooldown = Duration(seconds: 10);
  final ValueNotifier<bool> _coolingDown = ValueNotifier(false);
  Timer? _cooldownTimer;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  Timer? _searchDebounce;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();

    store.addListener(_onStoreChanged);
    store.runVersion.addListener(_onRunFinished);
    HardwareKeyboard.instance.addHandler(_onKey);

    // Tạm dừng auto-refresh khi tab bị ẩn; quay lại thì check nếu đã quá hạn.
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) return;
      final last = store.lastRun;
      if (last == null || DateTime.now().difference(last) >= _refreshInterval) {
        _refresh(manual: false);
      }
    });

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (html.document.hidden != true) _refresh(manual: false);
    });

    _initialLoad();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _visibilitySub?.cancel();
    _searchDebounce?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    store.removeListener(_onStoreChanged);
    store.runVersion.removeListener(_onRunFinished);
    store.dispose();
    shots.dispose();
    visits.dispose();
    _cooldownTimer?.cancel();
    _coolingDown.dispose();
    _spin.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _initialLoad() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    await store.loadLastSeen();

    try {
      final data = await WebsiteService.fetchWebsites();
      if (!mounted) return;

      setState(() {
        all = data;
        _listVersion++;
        loading = false;
      });

      // Tắt stagger sau lần hiển thị đầu.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _stagger = false;
      });

      // Lần đầu vào trang → tự mở hướng dẫn (sau khi card đã hiện xong).
      if (!OnboardingTour.seen) {
        Future.delayed(const Duration(milliseconds: 1600), _startTour);
      }

      final urls = data.map((e) => e.url.trim()).toList();
      store.refreshAll(data);
      shots.fetchAll(urls);
    } catch (e) {
      debugPrint('[INITIAL LOAD ERROR] $e');
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// manual = true: POST /api/screenshot/refresh (tất cả) + check-status lại,
  ///   hiện "Checking…" cho mọi card, khóa nút 10s.
  /// auto (60s): chỉ check-status, giữ trạng thái cũ, cập nhật tại chỗ.
  Future<void> _refresh({bool manual = true}) async {
    if (!mounted || _fetching || store.running) return;
    if (manual && _coolingDown.value) return;
    if (loadError != null && all.isEmpty) return _initialLoad();

    if (manual) {
      _coolingDown.value = true;
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(_refreshCooldown, () {
        if (mounted) _coolingDown.value = false;
      });
    }

    var listChanged = false;
    _fetching = true;
    try {
      final data = await WebsiteService.fetchWebsites();
      if (!mounted) return;

      if (!isSameWebsiteList(all, data)) {
        listChanged = true;
        setState(() {
          all = data;
          _listVersion++;
        });
        final keep = data.map((e) => e.url.trim()).toSet();
        store.retain(keep);
        shots.retain(keep);
      }
    } catch (e) {
      debugPrint('[REFRESH ERROR] $e');
    } finally {
      _fetching = false;
    }

    if (!mounted) return;
    final urls = all.map((e) => e.url.trim()).toList();

    if (manual) {
      shots.refreshAll(urls);
    } else if (listChanged) {
      shots.fetchAll(urls);
    }

    await store.refreshAll(all, markChecking: manual);
  }

  bool isSameWebsiteList(List<Website> a, List<Website> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.name != y.name ||
          x.url != y.url ||
          x.type != y.type ||
          x.icon != y.icon ||
          x.iconUrl != y.iconUrl ||
          x.departmentName != y.departmentName) {
        return false;
      }
    }
    return true;
  }

  // ============================================================
  // STORE LISTENERS
  // ============================================================

  void _onStoreChanged() {
    if (store.running && !_spin.isAnimating && !Motion.reduced(context)) {
      _spin.repeat();
    } else if (!store.running && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  /// Card tự update tại chỗ; chỉ re-filter/sort (offline lên đầu) khi lượt check xong.
  void _onRunFinished() {
    if (mounted) setState(() {});
  }

  // ============================================================
  // KEYBOARD: "/" focus search
  // ============================================================

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Ctrl+B (⌘B trên Mac): đóng/mở sidebar — hoạt động cả khi đang gõ search.
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyB &&
        (kb.isControlPressed || kb.isMetaPressed) &&
        !kb.isShiftPressed &&
        !kb.isAltPressed) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
      if (MediaQuery.sizeOf(context).width < 900) return false; // màn hẹp
      _toggleSidebar();
      return true;
    }

    // "?" (Shift + /): mở hướng dẫn — trừ khi đang gõ trong ô tìm kiếm.
    if (event.character == '?') {
      if (_searchFocus.hasFocus) return false;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
      _startTour();
      return true;
    }

    if (event.character != '/' &&
        event.logicalKey != LogicalKeyboardKey.slash) {
      return false;
    }
    if (_searchFocus.hasFocus) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;

    _searchFocus.requestFocus();
    _searchCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchCtrl.text.length,
    );
    return true;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => query = value.trim().toLowerCase());
    });
  }

  // ============================================================
  // DERIVED DATA
  // ============================================================

  SiteStatus _st(Website w) => store.get(w.url.trim());

  bool _inDept(Website w) =>
      selectedDepartment == kAllDept || w.departmentName == selectedDepartment;

  bool _matchQuery(Website w) =>
      query.isEmpty ||
      '${w.name} ${w.url} ${w.departmentName}'.toLowerCase().contains(query);

  Object? _memoKey;
  List<Website> _memo = const [];

  List<Website> get filtered {
    final key = Object.hash(
      _listVersion,
      selectedDepartment,
      statusFilter,
      query,
      store.runVersion.value,
    );
    if (key == _memoKey) return _memo;

    final list = all.where((w) {
      if (!_inDept(w) || !_matchQuery(w)) return false;
      final s = _st(w);
      if (statusFilter == StatusFilter.online && !s.isReachable) return false;
      if (statusFilter == StatusFilter.offline && !s.isOffline) return false;
      return true;
    }).toList();

    // Thứ tự phòng ban (để nhóm) → offline lên đầu trong nhóm → tên.
    list.sort((a, b) {
      final d = deptRank(
        a.departmentName,
      ).compareTo(deptRank(b.departmentName));
      if (d != 0) return d;
      final n = a.departmentName.compareTo(b.departmentName);
      if (n != 0) return n;
      final oa = _st(a).isOffline ? 0 : 1;
      final ob = _st(b).isOffline ? 0 : 1;
      if (oa != ob) return oa.compareTo(ob);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _memoKey = key;
    _memo = list;
    return list;
  }

  List<DeptHealth> _deptHealth() {
    final names =
        all
            .map((e) => e.departmentName)
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) {
            final r = deptRank(a).compareTo(deptRank(b));
            return r != 0 ? r : a.compareTo(b);
          });

    DeptHealth build(String name, Iterable<Website> sites) {
      var online = 0;
      var offline = 0;
      var checking = 0;
      var unknown = 0;
      var total = 0;
      for (final w in sites) {
        total++;
        final s = store.get(w.url);
        if (s.isReachable) online++;
        if (s.isOffline) offline++;
        if (s.isChecking) checking++;
        if (s.isUnknown) unknown++;
      }
      return DeptHealth(
        name: name,
        total: total,
        online: online,
        offline: offline,
        checking: checking,
        unknown: unknown,
      );
    }

    return [
      build(kAllDept, all),
      for (final n in names) build(n, all.where((w) => w.departmentName == n)),
    ];
  }

  int? _medianLatency() {
    final l = [
      for (final w in all)
        if (_st(w).isReachable && _st(w).latencyMs != null) _st(w).latencyMs!,
    ]..sort();
    if (l.isEmpty) return null;
    final mid = l.length ~/ 2;
    return l.length.isOdd ? l[mid] : ((l[mid - 1] + l[mid]) / 2).round();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _open(Website w) {
    openInNewTab(w.url);
    visits.record(w.id);
  }

  void _openLive(Website w) {
    showPreviewDialog(
      context,
      website: w,
      status: store.of(w.url.trim()),
      onRecapture: () => shots.refreshOne(w.url.trim()),
    );
  }

  void _selectDept(String v) {
    if (v == selectedDepartment) return;
    setState(() => selectedDepartment = v);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 900;
    final pad = width < 600 ? 16.0 : 24.0;
    // Đủ chỗ (sidebar + tiêu đề + search 260 + filter + refresh) → 1 hàng.
    final sideW = narrow
        ? 0.0
        : (_sidebarCollapsed ? Sidebar.railWidth : Sidebar.wideWidth);
    final inlineTools = width - sideW >= 948;

    Widget sidebar({required bool compact}) => ListenableBuilder(
      key: _tk.sidebar,
      listenable: store,
      builder: (context, _) => Sidebar(
        departments: _deptHealth(),
        selected: selectedDepartment,
        online: all.where((w) => _st(w).isReachable).length,
        total: all.length,
        compact: compact,
        collapsed: _sidebarCollapsed,
        onToggleCollapsed: _toggleSidebar,
        onSelect: _selectDept,
      ),
    );

    final scroll = CustomScrollView(
      slivers: [
        if (narrow) SliverToBoxAdapter(child: sidebar(compact: true)),

        // Header (màn rộng: search + filter nằm cùng hàng tiêu đề)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, narrow ? 12 : 16, pad, 0),
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => _Header(
                tourKeys: _tk,
                onHelp: _startTour,
                tools: inlineTools
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, t) in _toolbarItems(
                            searchWidth: 260,
                          ).indexed) ...[
                            if (i > 0) const SizedBox(width: 10),
                            t,
                          ],
                        ],
                      )
                    : null,
                online: all.where((w) => _st(w).isReachable).length,
                offline: all.where((w) => _st(w).isOffline).length,
                total: all.length,
                medianMs: _medianLatency(),
                running: store.running,
                lastRun: store.lastRun,
                coolingDown: _coolingDown,
                spin: _spin,
                onRefresh: () => _refresh(manual: true),
                showPreview: _showPreview,
                onTogglePreview: _togglePreviewAll,
              ),
            ),
          ),
        ),

        // Frequently visited
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: Listenable.merge([store, visits]),
            builder: (context, _) => _frequent(pad),
          ),
        ),

        // Toolbar (chỉ khi không gom được vào header)
        if (!inlineTools)
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => _toolbar(pad, narrow),
            ),
          ),

        // Offline banner
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => _offlineBanner(pad),
          ),
        ),

        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
          sliver: _body(),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: c.bg,
      // Màn rộng: sidebar nằm ĐÈ lên nội dung (Stack). Nội dung chỉ đổi lề
      // trái 1 lần khi bấm đóng/mở → lưới card layout lại đúng 1 lần, còn
      // animation độ rộng chỉ chạy trên sidebar → mượt, không lag.
      body: narrow
          ? scroll
          : Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(left: sideW),
                    child: scroll,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: sidebar(compact: false),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------
  // FREQUENTLY VISITED
  // ------------------------------------------------------------

  /// Ô tối đa cho site "tự động" (mở nhiều nhất). Site gắn sao không giới hạn.
  static const _autoFavSlots = 5;

  Widget _frequent(double pad) {
    // 1. Site gắn sao: luôn hiện (kể cả offline).
    final starred = all.where((w) => _starred.contains(w.id)).toList();
    // 2. Site mở nhiều nhất (30 ngày, đang online), chưa gắn sao →
    //    lấp cho đủ 5 ô.
    final auto =
        all
            .where(
              (w) =>
                  !_starred.contains(w.id) &&
                  _st(w).isReachable &&
                  visits.count(w.id) > 0,
            )
            .toList()
          ..sort((a, b) => visits.count(b.id).compareTo(visits.count(a.id)));
    final free = (_autoFavSlots - starred.length).clamp(0, _autoFavSlots);

    final items = _applyFavOrder([...starred, ...auto.take(free)]);
    if (items.isEmpty) return const SizedBox.shrink();
    final c = context.dash;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
      // Cùng kiểu khung phòng ban: viền đen (Light) / trắng (Dark), bo 16.
      child: Container(
        key: _tk.frequent,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.text),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề: ★ Frequently visited · số site
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 9),
              child: Tooltip(
                message:
                    'Site đã gắn sao ★ (luôn hiện) + site bạn mở nhiều nhất '
                    'trong 30 ngày gần nhất. Kéo thả để đổi thứ tự.',
                child: Row(
                  children: [
                    const Icon(LucideIcons.star, size: 15, color: Brand.yellow),
                    const SizedBox(width: 7),
                    Text(
                      'Frequently visited',
                      style: displayText(
                        size: 15,
                        weight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${items.length}',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Dùng lại WebsiteCard (giống hệt card trong lưới: preview, chấm
            // trạng thái, nút mở/copy, theo nút ẩn/hiện preview ở header).
            // Độ rộng card theo cùng quy tắc lưới (tối thiểu 260px); không đủ
            // chỗ cho cả 5 → cuộn ngang.
            LayoutBuilder(
              builder: (context, cons) {
                const gap = 12.0;
                const minW = 260.0;
                final fit = ((cons.maxWidth + gap) / (minW + gap))
                    .floor()
                    .clamp(1, 99);
                final scroll = items.length > fit;
                final cardW = (cons.maxWidth - gap * (fit - 1)) / fit;

                final row = IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: scroll ? minW : cardW,
                          // Kéo thả để đổi thứ tự (lưu itpro.favOrder).
                          child: _FavSlot(
                            id: items[i].id,
                            width: scroll ? minW : cardW,
                            onDrop: (dragId) =>
                                _moveFav(items, dragId, items[i].id),
                            card: RepaintBoundary(
                              child: WebsiteCard(
                                key: ValueKey('freq-${items[i].id}'),
                                website: items[i],
                                status: store.of(items[i].url.trim()),
                                meta: shots.of(items[i].url.trim()),
                                showPreview: _showPreview,
                                onOpen: () => _open(items[i]),
                                onOpenLive: () => _openLive(items[i]),
                                starred: _starred.contains(items[i].id),
                                onToggleStar: () => _toggleStar(items[i]),
                                onRemove: () => _removeFav(items[i]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );

                return scroll
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: row,
                      )
                    : row;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOOLBAR
  // ------------------------------------------------------------

  Widget _toolbar(double pad, bool narrow) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _toolbarItems(searchWidth: narrow ? double.infinity : 320),
      ),
    );
  }

  /// Search + segmented; dùng chung cho toolbar riêng và header (màn rộng).
  List<Widget> _toolbarItems({required double searchWidth}) {
    var nAll = 0, nOn = 0, nOff = 0;
    for (final w in all) {
      if (!_inDept(w) || !_matchQuery(w)) continue;
      nAll++;
      final s = _st(w);
      if (s.isReachable) nOn++;
      if (s.isOffline) nOff++;
    }

    return [
      SizedBox(
        key: _tk.search,
        width: searchWidth,
        child: _SearchField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
        ),
      ),
      _Segmented(
        key: _tk.filter,
        value: statusFilter,
        onChanged: (v) => setState(() => statusFilter = v),
        items: [
          (StatusFilter.all, 'All', nAll),
          (StatusFilter.online, 'Online', nOn),
          (StatusFilter.offline, 'Offline', nOff),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------
  // OFFLINE BANNER
  // ------------------------------------------------------------

  Widget _offlineBanner(double pad) {
    final off = all.where((w) => _inDept(w) && _st(w).isOffline).toList();
    if (off.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.tone.bannerBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.tone.offBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                LucideIcons.circleAlert,
                size: 18,
                color: context.tone.offFg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${off.length} site offline: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: off
                          .map((w) => '${w.name} (${displayHost(w.url)})')
                          .join(', '),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: context.tone.bannerText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // GRID
  // ------------------------------------------------------------

  Widget _body() {
    if (loading) {
      return _cardGrid(
        itemCount: 8,
        itemBuilder: (_, _) => const _SkeletonCard(),
      );
    }

    if (loadError != null && all.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          icon: LucideIcons.wifiOff,
          title: 'Could not load websites',
          message: loadError!,
          action: FilledButton.icon(
            onPressed: _initialLoad,
            style: FilledButton.styleFrom(
              backgroundColor: context.dash.ink,
              foregroundColor: context.dash.onInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final data = filtered;
    if (data.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          icon: LucideIcons.searchX,
          title: 'No websites match',
          message: store.running && statusFilter != StatusFilter.all
              ? 'Status check in progress…'
              : 'Try another department, filter or search.',
        ),
      );
    }

    // Nhóm theo phòng ban (data đã sort theo phòng ban).
    final groups = <String, List<Website>>{};
    for (final w in data) {
      groups.putIfAbsent(w.departmentName, () => []).add(w);
    }

    // Thứ tự card toàn cục (cho stagger).
    final order = {for (var i = 0; i < data.length; i++) data[i].id: i};

    // Card đầu tiên làm mẫu cho bước "Thẻ website" của hướng dẫn.
    Widget card(Website w) => _Entrance(
      key: w.id == data.first.id ? _tk.card : ValueKey('card-${w.id}'),
      index: order[w.id] ?? 0,
      enabled: _stagger,
      // Hover/animation trong 1 card không repaint cả grid.
      child: RepaintBoundary(
        child: WebsiteCard(
          website: w,
          status: store.of(w.url.trim()),
          meta: shots.of(w.url.trim()),
          showPreview: _showPreview,
          onOpen: () => _open(w),
          onOpenLive: () => _openLive(w),
          starred: _starred.contains(w.id),
          onToggleStar: () => _toggleStar(w),
        ),
      ),
    );

    Widget header(String dept) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final inDept = all.where((w) => w.departmentName == dept);
        return _GroupHeader(
          name: dept.isEmpty ? 'Other' : dept,
          online: inDept.where((w) => _st(w).isReachable).length,
          offline: inDept.where((w) => _st(w).isOffline).length,
          total: inDept.length,
        );
      },
    );

    return _PackedGroups(
      groups: groups.entries.map((e) => (e.key, e.value)).toList(),
      cardBuilder: card,
      headerBuilder: header,
    );
  }

  /// grid-template-columns: repeat(auto-fill, minmax(270px, 1fr)); gap 14.
  /// Chia theo hàng để card có thể cao khác nhau (preview mở).
  Widget _cardGrid({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    const gap = 14.0;
    const minW = 270.0;
    return SliverLayoutBuilder(
      builder: (context, cons) {
        final cols = ((cons.crossAxisExtent + gap) / (minW + gap))
            .floor()
            .clamp(1, 99);
        final rows = (itemCount / cols).ceil();
        return SliverList.builder(
          itemCount: rows,
          itemBuilder: (context, r) => Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(
                    child: r * cols + j < itemCount
                        ? itemBuilder(context, r * cols + j)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PACKED GROUPS: nhóm nhỏ nằm cạnh nhau trên cùng 1 lưới cột
// ============================================================

/// Lưới auto-fill minmax(270px, 1fr), gap 14. Mỗi nhóm phòng ban là 1 khối
/// rộng đúng số card của nó (tối đa = số cột); các khối được xếp first-fit
/// vào hàng còn chỗ → nhóm 1–2 site không để trống cả hàng.
/// Cột card luôn thẳng hàng giữa các khối.
class _PackedGroups extends StatelessWidget {
  final List<(String, List<Website>)> groups;
  final Widget Function(Website) cardBuilder;
  final Widget Function(String dept) headerBuilder;

  const _PackedGroups({
    required this.groups,
    required this.cardBuilder,
    required this.headerBuilder,
  });

  /// Khoảng cách giữa card trong khung / giữa các khung.
  static const gap = 12.0;
  static const blockGap = 14.0;

  /// Lề trong khung (+1px viền).
  static const framePad = 11.0;
  static const minW = 260.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, cons) {
        final width = cons.crossAxisExtent;
        // 1 cột = 1 card + phần khung; khung span n = n cột + (n-1) blockGap.
        const overhead = framePad * 2 + 2;
        final cols = ((width + blockGap) / (minW + overhead + blockGap))
            .floor()
            .clamp(1, 99);
        final colW = (width - blockGap * (cols - 1)) / cols;

        // First-fit: đặt khối vào hàng đầu tiên còn đủ cột, giữ thứ tự phòng ban.
        final rows = <List<(String, List<Website>, int)>>[];
        final free = <int>[];
        for (final (dept, sites) in groups) {
          final span = sites.length.clamp(1, cols);
          var r = free.indexWhere((f) => f >= span);
          if (r < 0) {
            rows.add([]);
            free.add(cols);
            r = rows.length - 1;
          }
          rows[r].add((dept, sites, span));
          free[r] -= span;
        }

        return SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, r) => Padding(
            padding: EdgeInsets.only(
              bottom: r == rows.length - 1 ? 0 : blockGap,
            ),
            // Các khung trên cùng hàng CAO BẰNG NHAU (mép trên/dưới thẳng).
            // Card không còn AnimatedSize nên IntrinsicHeight an toàn; chỉ
            // chạy khi rebuild lưới (không chạy khi hover).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (dept, sites, span)) in rows[r].indexed) ...[
                    if (i > 0) const SizedBox(width: blockGap),
                    SizedBox(
                      width: span * colW + (span - 1) * blockGap,
                      child: _block(
                        context,
                        dept,
                        sites,
                        span,
                        span * colW + (span - 1) * blockGap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _block(
    BuildContext context,
    String dept,
    List<Website> sites,
    int span,
    double blockW,
  ) {
    final c = context.dash;
    final lines = (sites.length / span).ceil();
    // Trừ lề trong + viền 1px mỗi bên.
    final inner = blockW - framePad * 2 - 2;
    final cardW = (inner - gap * (span - 1)) / span;

    return Container(
      padding: const EdgeInsets.fromLTRB(framePad, 9, framePad, framePad),
      decoration: BoxDecoration(
        // Không dùng màu phòng ban: chỉ viền đen (Light) / trắng (Dark).
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.text),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 9),
            child: headerBuilder(dept),
          ),
          if (lines == 1)
            // 1 hàng card (khung nằm chung hàng với khung khác): card giãn
            // hết chiều cao khung → card ở các khung cạnh nhau cũng bằng nhau.
            Expanded(child: _cardLine(sites, 0, span, cardW))
          else
            for (var l = 0; l < lines; l++)
              Padding(
                padding: EdgeInsets.only(bottom: l == lines - 1 ? 0 : gap),
                // Card trong cùng hàng cao bằng nhau.
                child: IntrinsicHeight(child: _cardLine(sites, l, span, cardW)),
              ),
        ],
      ),
    );
  }

  /// 1 hàng card, card giãn theo chiều cao hàng (ảnh preview bám đáy card).
  Widget _cardLine(List<Website> sites, int l, int span, double cardW) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var j = 0; j < span && l * span + j < sites.length; j++) ...[
        if (j > 0) const SizedBox(width: gap),
        SizedBox(width: cardW, child: cardBuilder(sites[l * span + j])),
      ],
    ],
  );
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  final int online;
  final int offline;
  final int total;
  final int? medianMs;
  final bool running;
  final DateTime? lastRun;
  final ValueListenable<bool> coolingDown;
  final Animation<double> spin;
  final VoidCallback onRefresh;

  /// Search + filter đặt cùng hàng (màn rộng). null → toolbar riêng bên dưới.
  final Widget? tools;

  final bool showPreview;
  final VoidCallback onTogglePreview;

  final _TourKeys tourKeys;
  final VoidCallback onHelp;

  const _Header({
    required this.tourKeys,
    required this.onHelp,
    this.tools,
    required this.showPreview,
    required this.onTogglePreview,
    required this.online,
    required this.offline,
    required this.total,
    required this.medianMs,
    required this.running,
    required this.lastRun,
    required this.coolingDown,
    required this.spin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final updated = running
        ? 'đang kiểm tra…'
        : (lastRun != null ? 'cập nhật lúc ${hms(lastRun!)}' : 'chưa kiểm tra');
    // medianMs = độ trễ trung vị của các site online, hiển thị dạng dễ hiểu
    // "phản hồi ~X ms"; giải thích chi tiết ở tooltip.
    final rest = [
      if (medianMs != null) 'phản hồi ~$medianMs ms',
      updated,
    ].join(' · ');
    final tip = [
      '$online/$total site đang hoạt động'
          '${offline > 0 ? ', $offline site không truy cập được' : ''}.',
      if (medianMs != null)
        'Phản hồi ~$medianMs ms: thời gian một site thường mất để trả lời '
            '(một nửa số site nhanh hơn, một nửa chậm hơn). Càng nhỏ càng nhanh.',
      'Tự kiểm tra lại mỗi 60 giây.',
    ].join('\n');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Website Dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: displayText(
                  size: 21,
                  weight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                key: tourKeys.status,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: offline > 0 ? t.dotBad : t.dotOk,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: tip,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$online/$total online',
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(text: ' · $rest'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (tools != null) ...[const SizedBox(width: 16), tools!],
        const SizedBox(width: 10),
        _HeaderIconButton(
          key: tourKeys.help,
          icon: LucideIcons.circleHelp,
          tooltip: 'Hướng dẫn sử dụng (?)',
          active: false,
          onTap: onHelp,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          key: tourKeys.preview,
          icon: showPreview ? LucideIcons.image : LucideIcons.imageOff,
          tooltip: showPreview
              ? 'Ẩn preview tất cả site'
              : 'Hiện preview tất cả site',
          active: showPreview,
          onTap: onTogglePreview,
        ),
        const SizedBox(width: 8),
        _ThemeToggle(key: tourKeys.theme),
        const SizedBox(width: 8),
        ValueListenableBuilder<bool>(
          key: tourKeys.refresh,
          valueListenable: coolingDown,
          builder: (_, cooling, _) => _RefreshButton(
            spin: spin,
            running: running,
            coolingDown: cooling,
            onTap: onRefresh,
          ),
        ),
      ],
    );
  }
}

/// Nút icon 38px ở header (cùng kiểu nút theme). [active] = đang bật → nền
/// xám nhạt + icon đậm; tắt → icon xám.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Tooltip(
      message: tooltip,
      child: HoverSurface(
        onTap: onTap,
        radius: 10,
        color: active ? c.surface2 : c.surface,
        hoverColor: c.surface2,
        borderColor: c.border,
        child: SizedBox(
          width: 36,
          height: 36,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 18,
              color: active ? c.text : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút đổi Light/Dark: cùng kích thước & viền với Refresh.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final dark = context.isDark;

    return Tooltip(
      message: dark ? 'Chuyển sang Light' : 'Chuyển sang Dark',
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: () {
            final curtain = ThemeCurtain.of(context);
            if (curtain != null) {
              curtain.toggle();
            } else {
              ThemeController.toggle(Theme.of(context).brightness);
            }
          },
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 38,
            height: 38,
            child: AnimatedSwitcher(
              duration: Motion.of(context, const Duration(milliseconds: 300)),
              transitionBuilder: (child, a) => RotationTransition(
                turns: Tween(begin: .75, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Icon(
                dark ? LucideIcons.moon : LucideIcons.sun,
                key: ValueKey(dark),
                size: 18,
                color: dark ? Brand.yellow : c.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final Animation<double> spin;
  final bool running;
  final bool coolingDown;
  final VoidCallback onTap;

  const _RefreshButton({
    required this.spin,
    required this.running,
    required this.coolingDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final disabled = running || coolingDown;

    return Tooltip(
      message: coolingDown && !running
          ? 'Just refreshed — wait a few seconds'
          : 'Re-capture screenshots & re-check all sites',
      child: OutlinedButton.icon(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.text,
          disabledForegroundColor: c.muted,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: RotationTransition(
          turns: spin,
          child: const Icon(LucideIcons.refreshCw, size: 17),
        ),
        label: Text(running ? 'Checking…' : 'Refresh'),
      ),
    );
  }
}

// ============================================================
// GROUP HEADER (mỗi phòng ban)
// ============================================================

/// `KVH  ● 3/3` — chấm xanh nếu tất cả online, đỏ nếu có site offline.
class _GroupHeader extends StatelessWidget {
  final String name;
  final int online;
  final int offline;
  final int total;

  const _GroupHeader({
    required this.name,
    required this.online,
    required this.offline,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    return Row(
      children: [
        Text(
          name,
          style: displayText(size: 15, weight: FontWeight.w700, color: c.text),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: offline > 0
              ? '$online/$total online · $offline offline'
              : '$online/$total online',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: offline > 0 ? t.dotBad : t.dotOk,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$online/$total',
                style: TextStyle(
                  color: c.muted,
                  fontSize: 12.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// ============================================================
// FAV SLOT — kéo thả đổi thứ tự Frequently visited
// ============================================================

/// 1 ô trong Frequently visited: vừa kéo được (Draggable) vừa nhận thả
/// (DragTarget).
/// - Đang kéo: card bay theo chuột (bóng đổ), ô gốc mờ đi.
/// - Rê qua ô khác: ô đó hiện viền đậm → biết sẽ thả vào đâu.
/// - Bấm nhẹ (không kéo) vẫn dùng được nút / ảnh bình thường.
class _FavSlot extends StatelessWidget {
  final int id;
  final double width;
  final Widget card;
  final ValueChanged<int> onDrop;

  const _FavSlot({
    required this.id,
    required this.width,
    required this.card,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final over = candidates.isNotEmpty;
        return Stack(
          fit: StackFit.expand,
          children: [
            Draggable<int>(
              data: id,
              maxSimultaneousDrags: 1,
              // Card bay theo chuột: cùng cỡ, có bóng, hơi trong suốt.
              feedback: Material(
                color: Colors.transparent,
                elevation: 12,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: Opacity(
                  opacity: .94,
                  child: SizedBox(
                    width: width,
                    child: IntrinsicHeight(child: card),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: .3, child: card),
              child: MouseRegion(cursor: SystemMouseCursors.grab, child: card),
            ),
            // Viền chỉ chỗ thả.
            if (over)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.text, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================
// SEARCH / SEGMENTED
// ============================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  OutlineInputBorder _border(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: w),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          controller.clear();
          onChanged('');
          focusNode.unfocus();
        },
      },
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: TextStyle(color: c.text, fontSize: 13.5),
          cursorColor: c.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surface,
            hintText: 'Search name, URL, department',
            hintStyle: TextStyle(color: c.muted, fontSize: 13.5),
            prefixIcon: Icon(LucideIcons.search, size: 18, color: c.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            suffixIcon: value.text.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '/',
                        style: TextStyle(color: c.muted, fontSize: 11.5),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(LucideIcons.x, size: 16, color: c.muted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            enabledBorder: _border(c.border),
            focusedBorder: _border(c.faint, 1.2),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final StatusFilter value;
  final ValueChanged<StatusFilter> onChanged;
  final List<(StatusFilter, String, int)> items;

  const _Segmented({
    super.key,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final d = Motion.of(context, Motion.fast);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, label, count) in items)
            Semantics(
              selected: key == value,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(key),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: d,
                    curve: Motion.curve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: key == value ? c.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: key == value ? c.onInk : c.text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: key == value
                                ? c.onInk.withValues(alpha: .7)
                                : (key == StatusFilter.offline && count > 0
                                      ? context.tone.offFg
                                      : c.muted),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ENTRANCE (stagger 1 lần)
// ============================================================

class _Entrance extends StatefulWidget {
  final int index;
  final bool enabled;
  final Widget child;

  const _Entrance({
    super.key,
    required this.index,
    required this.enabled,
    required this.child,
  });

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  late bool _shown = !widget.enabled;

  @override
  void initState() {
    super.initState();
    if (!_shown) {
      final delay = Duration(milliseconds: 40 * widget.index.clamp(0, 16));
      Future.delayed(delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final d = Motion.of(context, const Duration(milliseconds: 320));
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: d,
      curve: Motion.curve,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, .04),
        duration: d,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// DEPT EXAMPLE — hình minh hoạ phòng ban trong hướng dẫn
// ============================================================

enum _DeptExampleMode { row, rail, chip }

/// Phòng "KVH" mẫu: 5 site, 2 site offline — vẽ giống hệt sidebar thật
/// theo kiểu đang hiển thị (hàng mở rộng / ô thu gọn / chip màn hẹp).
class _DeptExample extends StatelessWidget {
  final _DeptExampleMode mode;
  const _DeptExample({required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    Widget pill(String text, Color fg, Color bg, {IconData? icon}) => Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );

    Widget arrow(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.arrowUp, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    switch (mode) {
      case _DeptExampleMode.row:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'KVH',
                      style: displayText(
                        size: 10,
                        weight: FontWeight.w700,
                        color: c.textSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KVH',
                      style: TextStyle(
                        color: c.textSoft,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  pill('2', t.offFg, t.offBg, icon: LucideIcons.wifiOff),
                  const SizedBox(width: 4),
                  pill('5', c.muted, c.surface2),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                arrow('2 site lỗi', t.offFg),
                const SizedBox(width: 10),
                arrow('tổng 5 site', c.muted),
                const SizedBox(width: 2),
              ],
            ),
          ],
        );

      case _DeptExampleMode.rail:
        return Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'KVH',
                    style: displayText(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: c.textSoft,
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15),
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.offFg,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.bg, width: 1.5),
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Icon(LucideIcons.arrowLeft, size: 12, color: t.offFg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Phòng KVH có 2 site lỗi',
                style: TextStyle(
                  color: t.offFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case _DeptExampleMode.chip:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'KVH',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('5', style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(width: 6),
                  Icon(LucideIcons.wifiOff, size: 11, color: t.offFg),
                  const SizedBox(width: 2),
                  Text(
                    '2',
                    style: TextStyle(
                      color: t.offFg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Số xám 5 = tổng site · số đỏ 2 = site đang lỗi',
              style: TextStyle(color: c.muted, fontSize: 11.5),
            ),
          ],
        );
    }
  }
}

// ============================================================
// SKELETON / EMPTY
// ============================================================

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    Widget bar(double w, double h, [double r = 4]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    // Không đặt chiều cao cố định → tự cao theo nội dung, không thể overflow
    // dù đổi cỡ icon / font.
    // Cùng hình dạng card: ảnh 16:9 + hàng icon · tên · địa chỉ.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                bar(44, 44, 11),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(120, 11),
                    const SizedBox(height: 7),
                    bar(150, 9),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ScreenFrame(child: Shimmer()),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c.muted),
          const SizedBox(height: 12),
          Text(title, style: displayText(size: 16, color: c.text)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
