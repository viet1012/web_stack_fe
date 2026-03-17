import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/api_provider.dart';
import '../../models/api_endpoint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'api_detail_screen.dart';
import 'api_form_screen.dart';

class ApiListScreen extends StatefulWidget {
  const ApiListScreen({super.key});

  @override
  State<ApiListScreen> createState() => _ApiListScreenState();
}

class _ApiListScreenState extends State<ApiListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, provider, _) {
        final endpoints = provider.endpoints;
        final groups = provider.groups;

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────
            Container(
              color: AppTheme.bgSecondary,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  AppSearchBar(
                    controller: _searchController,
                    hint: 'Tìm endpoint...',
                    onChanged: provider.setSearch,
                  ),
                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 28,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _GroupChip(
                            label: 'Tất cả',
                            selected: provider.activeGroup == null,
                            onTap: () => provider.setGroup(null),
                          ),
                          ...groups.map(
                            (g) => _GroupChip(
                              label: g,
                              selected: provider.activeGroup == g,
                              onTap: () => provider.setGroup(
                                provider.activeGroup == g ? null : g,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 0),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : endpoints.isEmpty
                  ? EmptyState(
                      emoji: '🔌',
                      title: 'Chưa có endpoint nào',
                      subtitle: 'Nhấn + để thêm API endpoint',
                      action: ElevatedButton.icon(
                        onPressed: () => _navigateToAdd(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm endpoint'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: endpoints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ApiCard(
                        endpoint: endpoints[i],
                        isRunning: provider.isRunning,
                        onTap: () => _navigateToDetail(context, endpoints[i]),
                        onRun: () =>
                            _runAndNavigate(context, provider, endpoints[i]),
                        onEdit: () => _navigateToEdit(context, endpoints[i]),
                        onDelete: () =>
                            _delete(context, provider, endpoints[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAndNavigate(
    BuildContext context,
    ApiProvider provider,
    ApiEndpoint endpoint,
  ) async {
    final response = await provider.run(endpoint);
    if (response != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ApiDetailScreen(endpoint: endpoint, initialResponse: response),
        ),
      );
    }
  }

  void _navigateToDetail(BuildContext context, ApiEndpoint endpoint) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApiDetailScreen(endpoint: endpoint)),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApiFormScreen()),
    );
  }

  void _navigateToEdit(BuildContext context, ApiEndpoint endpoint) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApiFormScreen(endpoint: endpoint)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    ApiProvider provider,
    ApiEndpoint endpoint,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text(
          'Xóa endpoint?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Bạn chắc chắn muốn xóa "${endpoint.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.methodDelete),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await provider.remove(endpoint.id);
    }
  }
}

// ── API Card ─────────────────────────────────────────────────────────────────

class _ApiCard extends StatelessWidget {
  final ApiEndpoint endpoint;
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ApiCard({
    required this.endpoint,
    required this.isRunning,
    required this.onTap,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 0),
              child: Row(
                children: [
                  MethodBadge(method: endpoint.method),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      endpoint.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Path
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 0),
              child: Text(
                endpoint.path,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      endpoint.groupName,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _SmallIconBtn(icon: Icons.edit_outlined, onTap: onEdit),
                  const SizedBox(width: 4),
                  _SmallIconBtn(
                    icon: Icons.delete_outline,
                    onTap: onDelete,
                    color: AppTheme.methodDelete.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: isRunning ? null : onRun,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isRunning
                            ? AppTheme.bgTertiary
                            : AppTheme.accentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRunning)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppTheme.accentLight,
                              ),
                            )
                          else
                            const Icon(
                              Icons.play_arrow,
                              size: 12,
                              color: AppTheme.accentLight,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isRunning ? '...' : 'Run',
                            style: const TextStyle(
                              color: AppTheme.accentLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _SmallIconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Icon(icon, size: 13, color: color ?? AppTheme.textMuted),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentBg : AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accentLight : AppTheme.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
