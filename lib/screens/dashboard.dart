import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_stack/screens/port_screen.dart';
import '../models/website.dart';
import '../services/website_service.dart';
import '../widgets/rocket_loading_screen.dart';
import '../widgets/sidebar.dart';
import '../widgets/website_card.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Website> all = [];
  String selectedDepartment = "ALL";
  bool loading = true;
  bool showContent = false;
  String sortType = "type";
  bool isTreeMode = false;
  Map<String, bool> statusMap = {};

  Timer? _refreshTimer;

  // 🔥 Chỉ check lại URLs đang bị lỗi + URLs mới
  Set<String> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    load();
    _startSmartRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startSmartRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    try {
      final data = await WebsiteService.fetchWebsites();

      // 🔥 Tìm URLs mới (chưa có trong statusMap)
      final newUrls = data
          .map((e) => e.url)
          .where((url) => !statusMap.containsKey(url))
          .toSet();

      // 🔥 Chỉ check: URLs lỗi + URLs mới (không check lại toàn bộ)
      final urlsToCheck = {..._failedUrls, ...newUrls}.toList();

      final partialResult = urlsToCheck.isNotEmpty
          ? await WebsiteService.checkBatch(urlsToCheck)
          : <String, bool>{};

      if (!mounted) return;

      // 🔥 Merge vào map hiện tại
      final updatedMap = Map<String, bool>.from(statusMap)
        ..addAll(partialResult);

      // 🔥 Cập nhật danh sách URL đang fail để check lại lần sau
      _failedUrls = updatedMap.entries
          .where((e) => e.value == false)
          .map((e) => e.key)
          .toSet();

      final isSameList = isSameWebsiteList(all, data);
      final isSameMap = isSameStatus(statusMap, updatedMap);

      if (!isSameList || !isSameMap) {
        setState(() {
          if (!isSameList) all = data;
          if (!isSameMap) statusMap = updatedMap;
        });
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      showContent = false;
    });

    final data = await WebsiteService.fetchWebsites();
    final urls = data.map((e) => e.url).toList();
    final result = await WebsiteService.checkBatch(urls);

    _failedUrls = result.entries
        .where((e) => e.value == false)
        .map((e) => e.key)
        .toSet();

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    setState(() {
      all = data;
      loading = false;
      statusMap = result;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    setState(() => showContent = true);
  }

  bool isSameWebsiteList(List<Website> a, List<Website> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].url != b[i].url ||
          a[i].type != b[i].type ||
          a[i].departmentName != b[i].departmentName) {
        return false;
      }
    }

    return true;
  }

  bool isSameStatus(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }

    return true;
  }

  /// 🔥 Department list
  List<String> get departments {
    final set = all.map((e) => e.departmentName).toSet();
    return ["ALL", ...set];
  }

  /// 🔥 Filter + Sort
  List<Website> get filtered {
    List<Website> list = selectedDepartment == "ALL"
        ? List.from(all)
        : all.where((e) => e.departmentName == selectedDepartment).toList();

    if (sortType == "type") {
      list.sort((a, b) => a.type.compareTo(b.type));
    }

    return list;
  }

  /// 🔥 Group theo TYPE (cho Tree)
  Map<String, List<Website>> groupByType(List<Website> data) {
    final Map<String, List<Website>> result = {};

    for (var w in data) {
      result.putIfAbsent(w.type, () => []);
      result[w.type]!.add(w);
    }

    return result;
  }

  /// 🔥 TREE VIEW UI
  Widget buildTree(List<Website> data) {
    final grouped = groupByType(data);

    return ListView(
      children: grouped.entries.map((entry) {
        final type = entry.key;
        final list = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ExpansionTile(
            collapsedIconColor: Colors.white70,
            iconColor: Colors.blue,
            title: Row(
              children: [
                /// 🔥 Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(type, style: const TextStyle(color: Colors.blue)),
                ),

                const SizedBox(width: 10),

                /// 🔥 Count
                Text(
                  "(${list.length})",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    double itemWidth;

                    if (width < 600) {
                      itemWidth = width; // full mobile
                    } else if (width < 1000) {
                      itemWidth = width / 2 - 16;
                    } else {
                      itemWidth = 260;
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: list.map((w) {
                        return SizedBox(
                          width: itemWidth,
                          child: AspectRatio(
                            aspectRatio: 1.4,
                            child: WebsiteCard(
                              website: w,
                              isAlive: statusMap[w.url],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 🔥 TOOLBAR
  Widget buildToolbar() {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔥 MAIN ROW
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// LEFT: ICON + TITLE
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: isMobile ? 16 : 28,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "WEBSITE DASHBOARD",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 16 : 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// RIGHT: ACTIONS
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildBtn(
                      icon: Icons.sort,
                      label: "Sort",
                      active: sortType == "type",
                      activeColor: Colors.blue,
                      isMobile: isMobile,
                      onTap: () {
                        setState(() {
                          sortType = sortType == "type" ? "none" : "type";
                        });
                      },
                    ),

                    _buildBtn(
                      icon: isTreeMode ? Icons.grid_view : Icons.account_tree,
                      label: isTreeMode ? "Grid" : "Tree",
                      active: isTreeMode,
                      activeColor: Colors.green,
                      isMobile: isMobile,
                      onTap: () {
                        setState(() {
                          isTreeMode = !isTreeMode;
                        });
                      },
                    ),

                    _buildBtn(
                      icon: Icons.hub,
                      label: "Ports",
                      active: true,
                      activeColor: Colors.purple,
                      isMobile: isMobile,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PortScreen(websites: all),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBtn({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 5 : 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? activeColor.withOpacity(0.2) : Colors.white10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isMobile ? 14 : 16,
              color: active ? activeColor : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: active ? activeColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 🔥 MAIN CONTENT với Explosion Animation
          ExplodeTransition(
            show: showContent,
            child: Row(
              children: [
                /// 🔥 SIDEBAR
                Sidebar(
                  departments: departments,
                  selected: selectedDepartment,
                  onSelect: (v) => setState(() => selectedDepartment = v),
                ),

                /// 🔥 MAIN CONTENT
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0B132B),
                          Color(0xFF1C2541),
                          Color(0xFF0F172A),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        buildToolbar(),
                        const SizedBox(height: 16),

                        /// 🔥 CONTENT SWITCH
                        Expanded(
                          child: isTreeMode
                              ? buildTree(data)
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;

                                    int crossAxisCount;
                                    double childAspectRatio;

                                    if (width < 600) {
                                      crossAxisCount = 1; // mobile
                                      childAspectRatio = 1.3;
                                    } else if (width < 900) {
                                      crossAxisCount = 2; // tablet nhỏ
                                      childAspectRatio = 1.35;
                                    } else if (width < 1200) {
                                      crossAxisCount = 3; // tablet lớn
                                      childAspectRatio = 1.4;
                                    } else if (width < 1600) {
                                      crossAxisCount = 4; // desktop
                                      childAspectRatio = 1.45;
                                    } else {
                                      crossAxisCount = 5; // màn to
                                      childAspectRatio = 1.5;
                                    }

                                    return GridView.builder(
                                      itemCount: data.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                            childAspectRatio: childAspectRatio,
                                          ),
                                      itemBuilder: (_, i) {
                                        final w = data[i];
                                        return WebsiteCard(
                                          website: w,
                                          isAlive: statusMap[w.url],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🚀 ROCKET LOADING OVERLAY (hiện khi đang load)
          if (loading) const RocketLoadingScreen(),
        ],
      ),
    );
  }
}
