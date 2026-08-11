import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_stack/screens/port_screen.dart';
import '../models/website.dart';
import '../services/website_service.dart';
import '../widgets/DashboardBackgroundPainter.dart';
import '../widgets/rocket_loading_screen.dart';
import '../widgets/sidebar.dart';
import '../widgets/website_card.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // ============================================================
  // DATA
  // ============================================================

  List<Website> all = [];

  String selectedDepartment = "ALL";

  String sortType = "type";

  bool isTreeMode = false;

  Map<String, bool> statusMap = {};

  // ============================================================
  // LOADING STATE
  // ============================================================

  bool loading = true;

  bool showContent = false;

  bool _refreshing = false;

  bool _checkingStatus = false;

  // ============================================================
  // TIMER
  // ============================================================

  Timer? _refreshTimer;

  static const Duration _refreshInterval =
  Duration(seconds: 60);

  // ============================================================
  // REQUEST VERSION
  //
  // Dùng để bỏ response cũ nếu screen dispose / request mới hơn.
  // ============================================================

  int _requestVersion = 0;

  // ============================================================
  // URL STATE
  // ============================================================

  /// Chỉ check lại:
  /// - URL đang lỗi
  /// - URL mới
  Set<String> _failedUrls = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initialLoad();

    _startSmartRefresh();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _requestVersion++;

    _refreshTimer?.cancel();
    _refreshTimer = null;

    super.dispose();
  }

  // ============================================================
  // REFRESH TIMER
  // ============================================================

  void _startSmartRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      _refreshInterval,
          (_) {
        if (!mounted) {
          return;
        }

        if (_refreshing) {
          return;
        }

        _refresh();
      },
    );
  }

  // ============================================================
  // INITIAL LOAD
  //
  // Quan trọng:
  // 1. Load danh sách website
  // 2. Hiện UI NGAY
  // 3. Check status background
  // ============================================================

  Future<void> _initialLoad() async {
    if (!mounted) {
      return;
    }

    final requestVersion =
    ++_requestVersion;

    setState(() {
      loading = true;
      showContent = false;
    });

    try {
      // ========================================================
      // 1. FETCH WEBSITE LIST
      // ========================================================

      final data =
      await WebsiteService.fetchWebsites();

      if (!_isValidRequest(requestVersion)) {
        return;
      }

      // ========================================================
      // 2. HIỆN UI NGAY
      //
      // Không đợi check-batch.
      // ========================================================

      setState(() {
        all = data;

        loading = false;

        showContent = true;
      });

      // ========================================================
      // 3. CHECK ONLINE/OFFLINE BACKGROUND
      // ========================================================

      await _checkInitialStatuses(
        data,
        requestVersion,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[INITIAL LOAD ERROR] $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!_isValidRequest(requestVersion)) {
        return;
      }

      setState(() {
        loading = false;

        // Cho UI vẫn render thay vì bị kẹt Rocket.
        showContent = true;
      });
    }
  }

  // ============================================================
  // INITIAL STATUS CHECK
  // ============================================================

  Future<void> _checkInitialStatuses(
      List<Website> data,
      int requestVersion,
      ) async {
    if (_checkingStatus) {
      return;
    }

    final urls = data
        .map((e) => e.url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (urls.isEmpty) {
      return;
    }

    _checkingStatus = true;

    try {
      final result =
      await WebsiteService.checkBatch(
        urls,

        // Lần đầu nên check thật.
        force: true,
      );

      if (!_isValidRequest(requestVersion)) {
        return;
      }

      _failedUrls =
          result.entries
              .where(
                (e) => e.value == false,
          )
              .map(
                (e) => e.key,
          )
              .toSet();

      if (!isSameStatus(
        statusMap,
        result,
      )) {
        setState(() {
          statusMap = result;
        });
      }
    } catch (e) {
      debugPrint(
        '[INITIAL STATUS ERROR] $e',
      );
    } finally {
      _checkingStatus = false;
    }
  }

  // ============================================================
  // SMART REFRESH
  //
  // Mỗi 60 giây:
  // - fetch website list
  // - tìm URL mới
  // - re-check URL đang fail
  // - không check lại URL đang OK
  // ============================================================

  Future<void> _refresh() async {
    if (!mounted || _refreshing) {
      return;
    }

    _refreshing = true;

    final requestVersion =
    ++_requestVersion;

    try {
      // ========================================================
      // 1. LOAD LẠI LIST
      // ========================================================

      final data =
      await WebsiteService.fetchWebsites();

      if (!_isValidRequest(requestVersion)) {
        return;
      }

      // ========================================================
      // 2. URL HIỆN TẠI
      // ========================================================

      final currentUrls = data
          .map((e) => e.url.trim())
          .where((url) => url.isNotEmpty)
          .toSet();

      // ========================================================
      // 3. URL MỚI
      //
      // URL chưa từng có trong statusMap.
      // ========================================================

      final newUrls = currentUrls
          .where(
            (url) =>
        !statusMap.containsKey(url),
      )
          .toSet();

      // ========================================================
      // 4. URL CẦN CHECK
      //
      // Chỉ:
      // - đang fail
      // - mới
      // ========================================================

      final urlsToCheck = {
        ..._failedUrls.where(
          currentUrls.contains,
        ),
        ...newUrls,
      }.toList(growable: false);

      Map<String, bool> partialResult =
      const {};

      if (urlsToCheck.isNotEmpty) {
        partialResult =
        await WebsiteService.checkBatch(
          urlsToCheck,

          // Quan trọng:
          // bỏ cache 5 phút khi đang re-check URL fail.
          force: true,
        );
      }

      if (!_isValidRequest(requestVersion)) {
        return;
      }

      // ========================================================
      // 5. MERGE STATUS
      // ========================================================

      final updatedMap =
      Map<String, bool>.from(
        statusMap,
      );

      updatedMap.addAll(
        partialResult,
      );

      // ========================================================
      // 6. XÓA STATUS CỦA WEBSITE ĐÃ BỊ REMOVE
      // ========================================================

      updatedMap.removeWhere(
            (url, _) =>
        !currentUrls.contains(url),
      );

      // ========================================================
      // 7. UPDATE FAILED URL LIST
      // ========================================================

      _failedUrls =
          updatedMap.entries
              .where(
                (e) => e.value == false,
          )
              .map(
                (e) => e.key,
          )
              .toSet();

      // ========================================================
      // 8. CHỈ SETSTATE KHI CÓ THAY ĐỔI
      // ========================================================

      final listChanged =
      !isSameWebsiteList(
        all,
        data,
      );

      final statusChanged =
      !isSameStatus(
        statusMap,
        updatedMap,
      );

      if (listChanged ||
          statusChanged) {
        setState(() {
          if (listChanged) {
            all = data;
          }

          if (statusChanged) {
            statusMap = updatedMap;
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[REFRESH ERROR] $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _refreshing = false;
    }
  }

  // ============================================================
  // REQUEST VALIDATION
  // ============================================================

  bool _isValidRequest(
      int requestVersion,
      ) {
    return mounted &&
        requestVersion == _requestVersion;
  }

  // ============================================================
  // COMPARE WEBSITE LIST
  // ============================================================

  bool isSameWebsiteList(
      List<Website> a,
      List<Website> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      final oldItem = a[i];

      final newItem = b[i];

      if (oldItem.id != newItem.id ||
          oldItem.name != newItem.name ||
          oldItem.url != newItem.url ||
          oldItem.type != newItem.type ||
          oldItem.departmentName !=
              newItem.departmentName) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // COMPARE STATUS
  // ============================================================

  bool isSameStatus(
      Map<String, bool> a,
      Map<String, bool> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (final key in a.keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // DEPARTMENTS
  // ============================================================

  List<String> get departments {
    final set = all
        .map(
          (e) => e.departmentName,
    )
        .where(
          (e) => e.trim().isNotEmpty,
    )
        .toSet()
        .toList();

    set.sort();

    return [
      "ALL",
      ...set,
    ];
  }

  // ============================================================
  // FILTERED
  // ============================================================

  List<Website> get filtered {
    final List<Website> list;

    if (selectedDepartment == "ALL") {
      list =
      List<Website>.from(all);
    } else {
      list = all
          .where(
            (e) =>
        e.departmentName ==
            selectedDepartment,
      )
          .toList();
    }

    if (sortType == "type") {
      list.sort(
            (a, b) {
          final typeCompare =
          a.type.compareTo(
            b.type,
          );

          if (typeCompare != 0) {
            return typeCompare;
          }

          return a.name.compareTo(
            b.name,
          );
        },
      );
    }

    return list;
  }

  // ============================================================
  // GROUP BY TYPE
  // ============================================================

  Map<String, List<Website>> groupByType(
      List<Website> data,
      ) {
    final result =
    <String, List<Website>>{};

    for (final website in data) {
      result
          .putIfAbsent(
        website.type,
            () => <Website>[],
      )
          .add(website);
    }

    return result;
  }

  // ============================================================
  // TREE VIEW
  // ============================================================

  Widget buildTree(
      List<Website> data,
      ) {
    final grouped =
    groupByType(data);

    return ListView(
      children:
      grouped.entries.map(
            (entry) {
          final type =
              entry.key;

          final list =
              entry.value;

          return Container(
            margin:
            const EdgeInsets.only(
              bottom: 12,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white
                  .withOpacity(
                0.03,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                Colors.white10,
              ),
            ),
            child: ExpansionTile(
              collapsedIconColor:
              Colors.white70,

              iconColor:
              Colors.blue,

              title: Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.blue
                          .withOpacity(
                        0.15,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Text(
                      type,
                      style:
                      const TextStyle(
                        color:
                        Colors.blue,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Text(
                    "(${list.length})",
                    style:
                    const TextStyle(
                      color:
                      Colors.white70,
                    ),
                  ),
                ],
              ),

              children: [
                Padding(
                  padding:
                  const EdgeInsets.all(
                    12,
                  ),
                  child:
                  LayoutBuilder(
                    builder:
                        (
                        context,
                        constraints,
                        ) {
                      final width =
                          constraints
                              .maxWidth;

                      double itemWidth;

                      if (width < 600) {
                        itemWidth =
                            width;
                      } else if (width <
                          1000) {
                        itemWidth =
                            width / 2 -
                                16;
                      } else {
                        itemWidth =
                        260;
                      }

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,

                        children:
                        list.map(
                              (w) {
                            return SizedBox(
                              width:
                              itemWidth,

                              child:
                              AspectRatio(
                                aspectRatio:
                                1.4,

                                child:
                                WebsiteCard(
                                  website:
                                  w,

                                  isAlive:
                                  statusMap[
                                  w.url],
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget buildToolbar() {
    final width =
        MediaQuery.of(context)
            .size
            .width;

    final isMobile =
        width < 600;

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        // ========================================================
        // TITLE
        // ========================================================

        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.travel_explore,
                size:
                isMobile
                    ? 16
                    : 28,
                color:
                const Color(
                  0xFF3B82F6,
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  "WEBSITE DASHBOARD",
                  style:
                  TextStyle(
                    color:
                    Colors.white,

                    fontSize:
                    isMobile
                        ? 16
                        : 24,

                    fontWeight:
                    FontWeight.bold,

                    letterSpacing:
                    1.2,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // ACTIONS
        // ========================================================

        Flexible(
          child: Wrap(
            alignment:
            WrapAlignment.end,

            spacing: 10,

            runSpacing: 10,

            children: [
              // ==================================================
              // SORT
              // ==================================================

              _buildBtn(
                icon:
                Icons.sort,

                label:
                "Sort",

                active:
                sortType ==
                    "type",

                activeColor:
                Colors.blue,

                isMobile:
                isMobile,

                onTap: () {
                  setState(() {
                    sortType =
                    sortType ==
                        "type"
                        ? "none"
                        : "type";
                  });
                },
              ),

              // ==================================================
              // GRID / TREE
              // ==================================================

              _buildBtn(
                icon:
                isTreeMode
                    ? Icons.grid_view
                    : Icons
                    .account_tree,

                label:
                isTreeMode
                    ? "Grid"
                    : "Tree",

                active:
                isTreeMode,

                activeColor:
                Colors.green,

                isMobile:
                isMobile,

                onTap: () {
                  setState(() {
                    isTreeMode =
                    !isTreeMode;
                  });
                },
              ),

              // ==================================================
              // PORTS
              // ==================================================

              _buildBtn(
                icon:
                Icons.hub,

                label:
                "Ports",

                active:
                true,

                activeColor:
                Colors.purple,

                isMobile:
                isMobile,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                          PortScreen(
                            websites:
                            all,
                          ),
                    ),
                  );
                },
              ),

              // ==================================================
              // MANUAL REFRESH
              // ==================================================

              _buildBtn(
                icon:
                Icons.refresh_rounded,

                label:
                _refreshing
                    ? "Refreshing"
                    : "Refresh",

                active:
                _refreshing,

                activeColor:
                Colors.orange,

                isMobile:
                isMobile,

                onTap: () {
                  if (!_refreshing) {
                    _refresh();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _buildBtn({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius:
      BorderRadius.circular(
        20,
      ),

      child: Container(
        padding:
        EdgeInsets.symmetric(
          horizontal:
          isMobile
              ? 10
              : 12,

          vertical:
          isMobile
              ? 5
              : 6,
        ),

        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            20,
          ),

          color:
          active
              ? activeColor
              .withOpacity(
            0.2,
          )
              : Colors.white10,

          border:
          Border.all(
            color:
            active
                ? activeColor
                .withOpacity(
              .3,
            )
                : Colors
                .transparent,
          ),
        ),

        child: Row(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Icon(
              icon,

              size:
              isMobile
                  ? 14
                  : 16,

              color:
              active
                  ? activeColor
                  : Colors.white70,
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              label,

              style:
              TextStyle(
                fontSize:
                isMobile
                    ? 12
                    : 14,

                color:
                active
                    ? activeColor
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final data = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: Stack(
        children: [
          // ========================================================
          // BACKGROUND GRADIENT
          // ========================================================

          Positioned.fill(
            child: Container(
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
            ),
          ),

          // ========================================================
          // DASHBOARD PAINTER
          // ========================================================

          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: DashboardBackgroundPainter(),
              ),
            ),
          ),

          // ========================================================
          // MAIN CONTENT
          // ========================================================

          ExplodeTransition(
            show: showContent,
            child: Row(
              children: [
                // =================================================
                // SIDEBAR
                // =================================================

                Sidebar(
                  departments: departments,
                  selected: selectedDepartment,
                  onSelect: (value) {
                    setState(() {
                      selectedDepartment = value;
                    });
                  },
                ),

                // =================================================
                // CONTENT
                // =================================================

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        buildToolbar(),

                        const SizedBox(height: 16),

                        Expanded(
                          child: isTreeMode
                              ? buildTree(data)
                              : _buildGrid(data),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // LOADING
          // ========================================================

          if (loading)
            const RocketLoadingScreen(),
        ],
      ),
    );
  }

  // ============================================================
  // GRID
  // ============================================================

  Widget _buildGrid(
      List<Website> data,
      ) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No websites',
          style: TextStyle(
            color:
            Colors.white54,
            fontSize: 16,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        final width =
            constraints.maxWidth;

        int crossAxisCount;

        double childAspectRatio;

        if (width < 600) {
          crossAxisCount = 1;

          childAspectRatio =
          1.3;
        } else if (width < 900) {
          crossAxisCount = 2;

          childAspectRatio =
          1.35;
        } else if (width < 1200) {
          crossAxisCount = 3;

          childAspectRatio =
          1.4;
        } else if (width < 1600) {
          crossAxisCount = 4;

          childAspectRatio =
          1.45;
        } else {
          crossAxisCount = 5;

          childAspectRatio =
          1.5;
        }

        return GridView.builder(
          itemCount:
          data.length,

          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            crossAxisCount,

            crossAxisSpacing:
            16,

            mainAxisSpacing:
            16,

            childAspectRatio:
            childAspectRatio,
          ),

          itemBuilder:
              (
              context,
              index,
              ) {
            final website =
            data[index];

            return WebsiteCard(
              website:
              website,

              isAlive:
              statusMap[
              website.url],
            );
          },
        );
      },
    );
  }
}
