import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_stack/screens/port_screen.dart';
import '../models/website.dart';
import '../services/website_service.dart';
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

  /// 🔥 UI state
  String sortType = "type"; // none | type
  bool isTreeMode = false;
  List<Website> websites = [];
  Map<String, bool> statusMap = {};

  Timer? timer;

  @override
  void initState() {
    super.initState();

    load();

    /// 🔥 AUTO REFRESH TOÀN LIST
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final data = await WebsiteService.fetchWebsites();

      final urls = data.map((e) => e.url).toList();
      final result = await WebsiteService.checkBatch(urls);

      if (!mounted) return;

      final isSameList = isSameWebsiteList(all, data);
      final isSameMap = isSameStatus(statusMap, result);

      /// 🔥 chỉ update khi có thay đổi
      if (!isSameList || !isSameMap) {
        setState(() {
          if (!isSameList) {
            all = data;
          }

          if (!isSameMap) {
            statusMap = result;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void load() async {
    final data = await WebsiteService.fetchWebsites();

    final urls = data.map((e) => e.url).toList();

    final result = await WebsiteService.checkBatch(urls);
    setState(() {
      all = data;
      loading = false;
      statusMap = result;
    });
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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: list
                      .map(
                        (w) => SizedBox(
                          width: 260,
                          height: 170,
                          child: WebsiteCard(
                            website: w,
                            isAlive: statusMap[w.url],
                          ),
                        ),
                      )
                      .toList(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "🌐 WEBSITE DASHBOARD",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        Row(
          children: [
            /// 🔥 SORT BUTTON
            GestureDetector(
              onTap: () {
                setState(() {
                  sortType = sortType == "type" ? "none" : "type";
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: sortType == "type"
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.white10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sort,
                      size: 16,
                      color: sortType == "type" ? Colors.blue : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Sort Type",
                      style: TextStyle(
                        color: sortType == "type"
                            ? Colors.blue
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 🔥 TOGGLE TREE MODE
            GestureDetector(
              onTap: () {
                setState(() {
                  isTreeMode = !isTreeMode;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isTreeMode
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white10,
                ),
                child: Row(
                  children: [
                    Icon(
                      isTreeMode ? Icons.grid_view : Icons.account_tree,
                      size: 16,
                      color: isTreeMode ? Colors.green : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isTreeMode ? "Grid View" : "Tree View",
                      style: TextStyle(
                        color: isTreeMode ? Colors.green : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PortScreen(websites: all)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.purple.withOpacity(0.2),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.hub, size: 16, color: Colors.purple),
                    SizedBox(width: 6),
                    Text("Ports", style: TextStyle(color: Colors.purple)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
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
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        buildToolbar(),
                        const SizedBox(height: 16),

                        /// 🔥 CONTENT SWITCH
                        Expanded(
                          child: isTreeMode
                              ? buildTree(data)
                              : GridView.builder(
                                  itemCount: data.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 1.4,
                                      ),
                                  itemBuilder: (_, i) {
                                    final w = data[i];
                                    return WebsiteCard(
                                      website: data[i],
                                      isAlive: statusMap[w.url],
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
    );
  }
}
