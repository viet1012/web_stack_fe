import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/website_provider.dart';
import '../../models/website.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'website_form_screen.dart';

class WebsiteListScreen extends StatefulWidget {
  const WebsiteListScreen({super.key});

  @override
  State<WebsiteListScreen> createState() => _WebsiteListScreenState();
}

class _WebsiteListScreenState extends State<WebsiteListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteWebsite(BuildContext context, Website website) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text(
          'Xóa website?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Bạn chắc chắn muốn xóa "${website.name}"?',
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
      await context.read<WebsiteProvider>().remove(website.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebsiteProvider>(
      builder: (context, provider, _) {
        final websites = provider.websites;

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────
            Container(
              color: AppTheme.bgSecondary,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: AppTheme.statusOnline,
                        size: 8,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${provider.onlineCount} online  ·  ${provider._websites.length} total',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search
                  AppSearchBar(
                    controller: _searchController,
                    hint: 'Tìm kiếm website...',
                    onChanged: provider.setSearch,
                  ),
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
                  : websites.isEmpty
                  ? EmptyState(
                      emoji: '🌐',
                      title: 'Chưa có website nào',
                      subtitle: 'Nhấn + để thêm website đầu tiên',
                      action: ElevatedButton.icon(
                        onPressed: () => _navigateToAdd(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm website'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: websites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _WebsiteCard(
                        website: websites[i],
                        onOpen: () => _openUrl(websites[i].url),
                        onEdit: () => _navigateToEdit(context, websites[i]),
                        onDelete: () => _deleteWebsite(context, websites[i]),
                        onToggleOnline: () =>
                            provider.toggleOnline(websites[i].id),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WebsiteFormScreen()),
    );
  }

  void _navigateToEdit(BuildContext context, Website website) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebsiteFormScreen(website: website)),
    );
  }
}

// ── Private extensions ─────────────────────────────────────────────────────────

extension on WebsiteProvider {
  List<Website> get _websites => websites; // for count display
}

// ── Website Card ──────────────────────────────────────────────────────────────

class _WebsiteCard extends StatelessWidget {
  final Website website;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleOnline;

  const _WebsiteCard({
    required this.website,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
            child: Row(
              children: [
                // Favicon emoji
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      website.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        website.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        website.displayUrl,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status + Open button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onToggleOnline,
                      child: StatusDot(isOnline: website.isOnline),
                    ),
                    const SizedBox(width: 8),
                    _SmallButton(label: 'Mở ↗', onTap: onOpen),
                  ],
                ),
              ],
            ),
          ),

          // Tags + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 11),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: website.tags
                        .map((t) => TagChip(label: t))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.edit_outlined, onTap: onEdit),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.delete_outline,
                  onTap: onDelete,
                  color: AppTheme.methodDelete.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.accentLight,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Icon(icon, size: 14, color: color ?? AppTheme.textMuted),
      ),
    );
  }
}
