import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/website.dart';
import '../services/screenshot_store.dart';
import '../services/status_store.dart';
import '../services/website_service.dart';
import '../theme/dash_theme.dart';
import '../widgets/dash_ui.dart';
import '../widgets/team_art.dart';
import '../widgets/preview_dialog.dart';
import '../widgets/sidebar.dart';
import '../widgets/site_thumbnail.dart';
import '../widgets/website_card.dart';

enum StatusFilter { all, online, offline }

enum SortBy { name, status, latency }

enum ViewMode { grid, list, host }

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

  String selectedDepartment = kAllDept;
  StatusFilter statusFilter = StatusFilter.all;
  SortBy sortBy = SortBy.name;
  ViewMode viewMode = ViewMode.grid;
  String query = '';

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

      final urls = data.map((e) => e.url.trim()).toList();
      store.probeAll(urls);
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

    await store.probeAll(urls, markChecking: manual);
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

  bool get _dependsOnStatus =>
      statusFilter != StatusFilter.all ||
      sortBy == SortBy.status ||
      sortBy == SortBy.latency;

  /// Card tự update tại chỗ; chỉ re-filter/sort khi lượt check xong.
  void _onRunFinished() {
    if (mounted && _dependsOnStatus) setState(() {});
  }

  // ============================================================
  // KEYBOARD: "/" focus search
  // ============================================================

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.character != '/' && event.logicalKey != LogicalKeyboardKey.slash) {
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
  // DERIVED DATA (memoized)
  // ============================================================

  Object? _memoKey;
  List<Website> _memo = const [];

  List<Website> get filtered {
    final key = Object.hash(
      _listVersion,
      selectedDepartment,
      statusFilter,
      sortBy,
      query,
      _dependsOnStatus ? store.runVersion.value : 0,
    );
    if (key == _memoKey) return _memo;

    final list = all.where((w) {
      if (selectedDepartment != kAllDept &&
          w.departmentName != selectedDepartment) {
        return false;
      }
      if (statusFilter != StatusFilter.all) {
        final s = store.get(w.url.trim());
        if (statusFilter == StatusFilter.online && !s.isReachable) return false;
        if (statusFilter == StatusFilter.offline && !s.isOffline) return false;
      }
      if (query.isNotEmpty) {
        final hay =
            '${w.name} ${w.url} ${w.type} ${w.departmentName}'.toLowerCase();
        if (!hay.contains(query)) return false;
      }
      return true;
    }).toList();

    int byName(Website a, Website b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (sortBy) {
      case SortBy.name:
        list.sort(byName);
      case SortBy.status:
        int rank(Website w) => switch (store.get(w.url.trim()).state) {
              SiteState.offline => 0,
              SiteState.authRequired => 1,
              SiteState.unknown => 2,
              SiteState.checking => 3,
              SiteState.online => 4,
            };
        list.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : byName(a, b);
        });
      case SortBy.latency:
        int lat(Website w) => store.get(w.url.trim()).latencyMs ?? 1 << 30;
        list.sort((a, b) {
          final r = lat(a).compareTo(lat(b));
          return r != 0 ? r : byName(a, b);
        });
    }

    _memoKey = key;
    _memo = list;
    return list;
  }

  List<DeptHealth> _deptHealth() {
    final names = all
        .map((e) => e.departmentName)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    DeptHealth build(String name, Iterable<Website> sites) {
      // Cùng 1 nguồn state với card + header "X/Y online".
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

  void _openPreview(Website w) {
    showPreviewDialog(
      context,
      website: w,
      status: store.of(w.url.trim()),
      onRecapture: () => shots.refreshOne(w.url.trim()),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final narrow = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: c.bg,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, child) {
          final health = _deptHealth();
          final online =
              all.where((w) => store.get(w.url.trim()).isReachable).length;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!narrow)
                Sidebar(
                  departments: health,
                  selected: selectedDepartment,
                  online: online,
                  total: all.length,
                  onSelect: (v) => setState(() => selectedDepartment = v),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      online: online,
                      total: all.length,
                      running: store.running,
                      coolingDown: _coolingDown,
                      lastRun: store.lastRun,
                      narrow: narrow,
                      spin: _spin,
                      searchCtrl: _searchCtrl,
                      searchFocus: _searchFocus,
                      onSearch: _onSearchChanged,
                      statusFilter: statusFilter,
                      onStatusFilter: (v) => setState(() => statusFilter = v),
                      sortBy: sortBy,
                      onSort: (v) => setState(() => sortBy = v),
                      viewMode: viewMode,
                      onViewMode: (v) => setState(() => viewMode = v),
                      onRefresh: () => _refresh(manual: true),
                    ),
                    if (narrow) ...[
                      const SizedBox(height: 8),
                      DeptChipBar(
                        departments: health,
                        selected: selectedDepartment,
                        onSelect: (v) => setState(() => selectedDepartment = v),
                      ),
                    ],
                    Expanded(child: child!),
                  ],
                ),
              ),
            ],
          );
        },
        // Nội dung chính không rebuild theo từng kết quả probe.
        child: _Content(builder: _buildContent),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading) return const _SkeletonGrid();

    if (loadError != null && all.isEmpty) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load websites',
        message: loadError!,
        action: FilledButton.icon(
          onPressed: _initialLoad,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      );
    }

    final data = filtered;

    final Widget body;
    if (data.isEmpty) {
      body = _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No websites match',
        message: store.running && statusFilter != StatusFilter.all
            ? 'Status check in progress…'
            : 'Try another department, filter or search.',
      );
    } else {
      body = switch (viewMode) {
        ViewMode.grid => _buildGrid(data),
        ViewMode.list => _buildList(data),
        ViewMode.host => _buildByHost(data),
      };
    }

    // Tương đương View Transitions: cross-fade khi đổi filter/sort/view.
    return AnimatedSwitcher(
      duration: Motion.of(context),
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      child: KeyedSubtree(
        key: ValueKey(
          '$selectedDepartment|$statusFilter|$sortBy|$viewMode|${data.isEmpty}',
        ),
        child: body,
      ),
    );
  }

  // ============================================================
  // GRID: repeat(auto-fill, minmax(280px, 1fr)), gap 16
  // ============================================================

  Widget _buildGrid(List<Website> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600 ? 16.0 : 24.0;
        const gap = 16.0;
        const minW = 280.0;
        final width = constraints.maxWidth - pad * 2;
        final count = ((width + gap) / (minW + gap)).floor().clamp(1, 99);
        final itemW = (width - gap * (count - 1)) / count;
        final extent = itemW * 9 / 16 + kCardBodyHeight + 2;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
          itemCount: data.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, i) {
            final w = data[i];
            return _Entrance(
              key: ValueKey('grid-${w.id}'),
              index: i,
              enabled: _stagger,
              child: WebsiteCard(
                website: w,
                status: store.of(w.url.trim()),
                meta: shots.of(w.url.trim()),
                onPreview: () => _openPreview(w),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildList(List<Website> data) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
      itemCount: data.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final w = data[i];
        return _ListRow(
          key: ValueKey('list-${w.id}'),
          website: w,
          status: store.of(w.url.trim()),
          onPreview: () => _openPreview(w),
        );
      },
    );
  }

  // ============================================================
  // BY HOST (thay Tree / Ports)
  // ============================================================

  Widget _buildByHost(List<Website> data) {
    final c = context.dash;
    final groups = <String, List<Website>>{};
    for (final w in data) {
      groups.putIfAbsent(hostPort(w.url).host, () => []).add(w);
    }
    final hosts = groups.keys.toList()..sort();
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
      itemCount: hosts.length,
      itemBuilder: (context, i) {
        final host = hosts[i];
        final sites = groups[host]!
          ..sort((a, b) => (hostPort(a.url).port ?? 0)
              .compareTo(hostPort(b.url).port ?? 0));

        final portCount = <int?, int>{};
        for (final w in sites) {
          final p = hostPort(w.url).port;
          portCount[p] = (portCount[p] ?? 0) + 1;
        }
        final conflicts = portCount.values.where((n) => n > 1).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.dns_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: SelectableText(
                        host,
                        maxLines: 1,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DashChip(
                      label: '${sites.length} site${sites.length > 1 ? 's' : ''}'
                          ' · ${portCount.length} port${portCount.length > 1 ? 's' : ''}',
                    ),
                    if (conflicts > 0) ...[
                      const SizedBox(width: 6),
                      DashChip(
                        label: '$conflicts port conflict${conflicts > 1 ? 's' : ''}',
                        color: c.bad,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    for (final w in sites)
                      _ListRow(
                        key: ValueKey('host-${w.id}'),
                        website: w,
                        status: store.of(w.url.trim()),
                        onPreview: () => _openPreview(w),
                        dense: true,
                        portConflict:
                            (portCount[hostPort(w.url).port] ?? 0) > 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// CONTENT WRAPPER
// ============================================================

class _Content extends StatelessWidget {
  final WidgetBuilder builder;
  const _Content({required this.builder});

  @override
  Widget build(BuildContext context) => builder(context);
}

// ============================================================
// HEADER (sticky)
// ============================================================

class _Header extends StatelessWidget {
  final int online;
  final int total;
  final bool running;
  final ValueListenable<bool> coolingDown;
  final DateTime? lastRun;
  final bool narrow;
  final Animation<double> spin;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;
  final StatusFilter statusFilter;
  final ValueChanged<StatusFilter> onStatusFilter;
  final SortBy sortBy;
  final ValueChanged<SortBy> onSort;
  final ViewMode viewMode;
  final ValueChanged<ViewMode> onViewMode;
  final VoidCallback onRefresh;

  const _Header({
    required this.online,
    required this.total,
    required this.running,
    required this.coolingDown,
    required this.lastRun,
    required this.narrow,
    required this.spin,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSearch,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.sortBy,
    required this.onSort,
    required this.viewMode,
    required this.onViewMode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;

    final subtitle = StringBuffer('$online/$total online');
    if (running) {
      subtitle.write(' · checking…');
    } else if (lastRun != null) {
      subtitle.write(' · updated ${hms(lastRun!)}');
    }

    return Container(
      padding: EdgeInsets.fromLTRB(pad, 18, pad, 14),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Website Dashboard',
                      style: TextStyle(
                        color: c.text,
                        fontSize: narrow ? 18 : 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        StatusDot(
                          color: total > 0 && online == total ? c.ok : (running ? c.warn : c.bad),
                          size: 6,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            subtitle.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: coolingDown,
                builder: (_, cooling, _) => _RefreshButton(
                  spin: spin,
                  running: running,
                  coolingDown: cooling,
                  onTap: onRefresh,
                  compact: narrow,
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (_, mode, _) => DashIconButton(
                  icon: mode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  tooltip: mode == ThemeMode.dark ? 'Light theme' : 'Dark theme',
                  size: 18,
                  onPressed: ThemeController.toggle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: narrow ? double.infinity : 280,
                child: _SearchField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  onChanged: onSearch,
                ),
              ),
              _Segmented<StatusFilter>(
                value: statusFilter,
                onChanged: onStatusFilter,
                items: const {
                  StatusFilter.all: ('All', null),
                  StatusFilter.online: ('Online', null),
                  StatusFilter.offline: ('Offline', null),
                },
              ),
              _SortMenu(value: sortBy, onChanged: onSort),
              _Segmented<ViewMode>(
                value: viewMode,
                onChanged: onViewMode,
                items: const {
                  ViewMode.grid: ('Grid', Icons.grid_view_rounded),
                  ViewMode.list: ('List', Icons.view_list_rounded),
                  ViewMode.host: ('By host', Icons.dns_rounded),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
          cursorColor: c.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surface,
            hintText: 'Search websites',
            hintStyle: TextStyle(color: c.muted, fontSize: 13.5),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            suffixIcon: value.text.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('/', style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ),
                  )
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(Icons.close_rounded, size: 16, color: c.muted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            enabledBorder: _border(c.border),
            focusedBorder: _border(c.accent, 1.5),
          ),
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, (String, IconData?)> items;

  const _Segmented({
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
          for (final e in items.entries)
            Semantics(
              selected: e.key == value,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(e.key),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: d,
                    curve: Motion.curve,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: e.key == value ? c.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.value.$2 != null) ...[
                          Icon(
                            e.value.$2,
                            size: 15,
                            color: e.key == value ? Colors.white : c.muted,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          e.value.$1,
                          style: TextStyle(
                            color: e.key == value ? Colors.white : c.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
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

class _SortMenu extends StatelessWidget {
  final SortBy value;
  final ValueChanged<SortBy> onChanged;

  const _SortMenu({required this.value, required this.onChanged});

  static const _labels = {
    SortBy.name: 'Name',
    SortBy.status: 'Status',
    SortBy.latency: 'Latency',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return PopupMenuButton<SortBy>(
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      color: c.surface,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (_) => [
        for (final e in _labels.entries)
          PopupMenuItem(
            value: e.key,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: e.key == value
                      ? Icon(Icons.check_rounded, size: 16, color: c.accent)
                      : null,
                ),
                Text(e.value, style: TextStyle(color: c.text, fontSize: 13)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: c.muted),
            const SizedBox(width: 6),
            Text(
              'Sort: ${_labels[value]}',
              style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: c.muted),
          ],
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
  final bool compact;

  const _RefreshButton({
    required this.spin,
    required this.running,
    required this.coolingDown,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final icon = RotationTransition(
      turns: spin,
      child: const Icon(Icons.refresh_rounded, size: 17),
    );
    final style = FilledButton.styleFrom(
      backgroundColor: c.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: c.accent.withValues(alpha: .55),
      disabledForegroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    final disabled = running || coolingDown;

    return Tooltip(
      message: coolingDown && !running
          ? 'Just refreshed — wait a few seconds'
          : 'Re-capture screenshots & re-check all sites',
      child: compact
          ? FilledButton(onPressed: disabled ? null : onTap, style: style, child: icon)
          : FilledButton.icon(
              onPressed: disabled ? null : onTap,
              style: style,
              icon: icon,
              label: Text(running ? 'Checking…' : 'Refresh'),
            ),
    );
  }
}

// ============================================================
// LIST ROW
// ============================================================

class _ListRow extends StatefulWidget {
  final Website website;
  final ValueListenable<SiteStatus> status;
  final VoidCallback onPreview;
  final bool dense;
  final bool portConflict;

  const _ListRow({
    super.key,
    required this.website,
    required this.status,
    required this.onPreview,
    this.dense = false,
    this.portConflict = false,
  });

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final w = widget.website;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final port = hostPort(w.url).port;

    return ValueListenableBuilder<SiteStatus>(
      valueListenable: widget.status,
      builder: (context, s, _) {
        final dotColor = switch (s.state) {
          SiteState.online => c.ok,
          SiteState.offline => c.bad,
          SiteState.checking || SiteState.authRequired => c.warn,
          SiteState.unknown => c.muted,
        };

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPreview,
            onHover: (v) => setState(() => _hover = v),
            borderRadius: BorderRadius.circular(10),
            focusColor: c.accent.withValues(alpha: .14),
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curve,
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: widget.dense ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: widget.dense
                    ? (_hover ? c.surface2 : Colors.transparent)
                    : (_hover ? c.surface2 : c.surface),
                borderRadius: BorderRadius.circular(10),
                border: widget.dense
                    ? null
                    : Border(
                        left: BorderSide(
                          color: s.isReachable ? tagColor(w.type) : c.border,
                          width: 3,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  if (widget.dense)
                    Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (widget.portConflict ? c.bad : c.accent)
                            .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        port == null ? 'default' : ':$port',
                        style: TextStyle(
                          color: widget.portConflict ? c.bad : c.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  StatusDot(color: dotColor, pulse: s.isOnline, size: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Tooltip(
                          message: w.url,
                          child: Text(
                            w.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 12),
                    TagChip(w.type),
                    if (w.departmentName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      DashChip(label: w.departmentName),
                    ],
                    SizedBox(
                      width: 92,
                      child: Text(
                        switch (s.state) {
                          SiteState.online => '${s.latencyMs ?? '–'} ms',
                          SiteState.offline => s.lastSeen == null
                              ? 'offline'
                              : 'seen ${relativeTime(s.lastSeen)}',
                          SiteState.checking => 'checking…',
                          SiteState.authRequired => 'login required',
                          SiteState.unknown => 'not checked',
                        },
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: s.isOffline ? c.bad : c.muted,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  DashIconButton(
                    icon: Icons.content_copy_rounded,
                    tooltip: 'Copy URL',
                    size: 15,
                    onPressed: () => copyUrl(context, w.url),
                  ),
                  DashIconButton(
                    icon: Icons.open_in_new_rounded,
                    tooltip: 'Open in new tab',
                    size: 16,
                    onPressed: () => openInNewTab(w.url),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
// SKELETON / EMPTY
// ============================================================

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600 ? 16.0 : 24.0;
        const gap = 16.0;
        final width = constraints.maxWidth - pad * 2;
        final count = ((width + gap) / (280 + gap)).floor().clamp(1, 99);
        final itemW = (width - gap * (count - 1)) / count;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
          itemCount: count * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: itemW * 9 / 16 + kCardBodyHeight + 2,
          ),
          itemBuilder: (_, _) => Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(aspectRatio: 16 / 9, child: Shimmer()),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(c, 140, 12),
                      const SizedBox(height: 8),
                      _bar(c, 200, 9),
                      const SizedBox(height: 18),
                      _bar(c, 70, 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(DashColors c, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(4),
        ),
      );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
