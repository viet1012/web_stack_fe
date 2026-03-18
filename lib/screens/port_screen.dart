import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/website.dart';

class PortScreen extends StatefulWidget {
  final List<Website> websites;

  const PortScreen({super.key, required this.websites});

  @override
  State<PortScreen> createState() => _PortScreenState();
}

class _PortScreenState extends State<PortScreen> {
  final Set<String> expandedHosts = {};
  final Set<String> expandedPorts = {};
  String? hoveredKey;

  ({String host, int port})? extract(String url) {
    try {
      final uri = Uri.parse(url.startsWith("http") ? url : "http://$url");
      if (uri.port == 0) return null;
      return (host: uri.host, port: uri.port);
    } catch (_) {
      return null;
    }
  }

  Map<String, Map<int, List<Website>>> buildTree() {
    final Map<String, Map<int, List<Website>>> tree = {};

    for (var w in widget.websites) {
      final hp = extract(w.url);
      if (hp == null) continue;

      tree.putIfAbsent(hp.host, () => {});
      tree[hp.host]!.putIfAbsent(hp.port, () => []);
      tree[hp.host]![hp.port]!.add(w);
    }

    return tree;
  }

  List<int> suggestForHost(Map<int, List<Website>> ports) {
    final used = ports.keys.toSet();
    final result = <int>[];

    for (int i = 3000; i <= 9000; i++) {
      if (!used.contains(i)) {
        result.add(i);
      }
      if (result.length >= 10) break;
    }

    return result;
  }

  int getTotalWebsites() {
    return widget.websites.length;
  }

  int getTotalPorts() {
    final tree = buildTree();
    int total = 0;
    tree.forEach((host, ports) {
      total += ports.length;
    });
    return total;
  }

  int getConflictCount() {
    final tree = buildTree();
    int conflicts = 0;
    tree.forEach((host, ports) {
      ports.forEach((port, websites) {
        if (websites.length > 1) conflicts++;
      });
    });
    return conflicts;
  }

  @override
  Widget build(BuildContext context) {
    final tree = buildTree();
    final totalWebsites = getTotalWebsites();
    final totalPorts = getTotalPorts();
    final conflicts = getConflictCount();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF334155),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER với Glass Effect
              _buildHeader(context, totalWebsites, totalPorts, conflicts),

              const SizedBox(height: 16),

              // STATISTICS CARDS
              _buildStatisticsCards(totalWebsites, totalPorts, conflicts),

              const SizedBox(height: 16),

              // MAIN CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: tree.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: tree.entries.length,
                          itemBuilder: (context, index) {
                            final hostEntry = tree.entries.elementAt(index);
                            return _buildHostCard(hostEntry);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int totalWebsites,
    int totalPorts,
    int conflicts,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          color: Colors.cyanAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "PORT MANAGER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Quản lý cổng kết nối và phát hiện xung đột",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(
    int totalWebsites,
    int totalPorts,
    int conflicts,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.language,
              label: "Tổng Website",
              value: "$totalWebsites",
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.settings_ethernet,
              label: "Tổng Port",
              value: "$totalPorts",
              color: Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.warning_amber_rounded,
              label: "Xung đột",
              value: "$conflicts",
              color: conflicts > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHostCard(MapEntry<String, Map<int, List<Website>>> hostEntry) {
    final host = hostEntry.key;
    final ports = hostEntry.value;
    final isExpanded = expandedHosts.contains(host);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                // HOST HEADER
                InkWell(
                  onTap: () {
                    setState(() {
                      isExpanded
                          ? expandedHosts.remove(host)
                          : expandedHosts.add(host);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.dns,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host,
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${ports.length} cổng đang sử dụng",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),

                // EXPANDED CONTENT
                if (isExpanded) ...[
                  Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SUGGESTED PORTS
                        _buildSuggestionSection(host, ports),

                        const SizedBox(height: 16),

                        // PORTS LIST
                        ...ports.entries.map((portEntry) {
                          return _buildPortItem(host, portEntry);
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionSection(String host, Map<int, List<Website>> ports) {
    final suggested = suggestForHost(ports);

    if (suggested.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              "Cổng khả dụng (nhấn để copy)",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggested.map((p) {
            return _buildSuggestedPortChip(host, p);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestedPortChip(String host, int port) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: "$port"));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text("Đã copy: $host:$port"),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.greenAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$port",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.copy,
              size: 14,
              color: Colors.greenAccent.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortItem(String host, MapEntry<int, List<Website>> portEntry) {
    final port = portEntry.key;
    final list = portEntry.value;
    final portKey = "$host:$port";
    final isPortExpanded = expandedPorts.contains(portKey);
    final isConflict = list.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConflict
              ? Colors.red.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        color: isConflict
            ? Colors.red.withOpacity(0.05)
            : Colors.white.withOpacity(0.03),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isPortExpanded
                    ? expandedPorts.remove(portKey)
                    : expandedPorts.add(portKey);
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isConflict
                          ? Colors.red.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.settings_ethernet,
                      color: isConflict ? Colors.red : Colors.blue,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Port $port",
                              style: TextStyle(
                                color: isConflict ? Colors.red : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (isConflict) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  "XUNG ĐỘT",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${list.length} website${list.length > 1 ? 's' : ''}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 18,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: "$port"));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                              ),
                              const SizedBox(width: 8),
                              Text("Đã copy port: $port"),
                            ],
                          ),
                          backgroundColor: Colors.green.shade800,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                  Icon(
                    isPortExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // WEBSITES LIST
          if (isPortExpanded)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: list.map((w) {
                  return _buildWebsiteItem(w);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebsiteItem(Website w) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: w.url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Đã copy URL: ${w.url}",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.web, color: Colors.purple, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.url,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 16, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "Không có dữ liệu port",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Thêm website để bắt đầu",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
