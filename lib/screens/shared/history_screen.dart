import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/api_provider.dart';
import '../../models/api_endpoint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../apis/api_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, provider, _) {
        final history = provider.history;

        return Column(
          children: [
            if (history.isNotEmpty)
              Container(
                color: AppTheme.bgSecondary,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Text(
                      '${history.length} requests',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _confirmClear(context, provider),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Xóa lịch sử'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.methodDelete,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 0),
            Expanded(
              child: history.isEmpty
                  ? const EmptyState(
                      emoji: '📋',
                      title: 'Chưa có lịch sử',
                      subtitle: 'Gọi API để xem lịch sử ở đây',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _HistoryItem(
                        response: history[i],
                        onTap: () => _showDetail(context, provider, history[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showDetail(
    BuildContext context,
    ApiProvider provider,
    ApiResponse response,
  ) {
    final endpoint = provider.getById(response.endpointId);
    if (endpoint == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ApiDetailScreen(endpoint: endpoint, initialResponse: response),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ApiProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text(
          'Xóa lịch sử?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Tất cả lịch sử API sẽ bị xóa.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.methodDelete),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );
    if (confirm == true) await provider.clearHistory();
  }
}

class _HistoryItem extends StatelessWidget {
  final ApiResponse response;
  final VoidCallback onTap;

  const _HistoryItem({required this.response, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final codeStr = response.statusCode == 0 ? 'ERR' : '${response.statusCode}';
    final codeColor = response.statusCode == 0
        ? AppTheme.methodDelete
        : codeStr.statusCodeColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: codeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  codeStr,
                  style: TextStyle(
                    color: codeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.endpointName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        response.durationLabel,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        response.sizeLabel,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _timeLabel(response.timestamp),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m trước';
    if (diff.inHours < 24) return '${diff.inHours}h trước';
    return '${dt.day}/${dt.month}';
  }
}
