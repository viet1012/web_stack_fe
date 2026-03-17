import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/api_provider.dart';
import '../../models/api_endpoint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ApiDetailScreen extends StatefulWidget {
  final ApiEndpoint endpoint;
  final ApiResponse? initialResponse;

  const ApiDetailScreen({
    super.key,
    required this.endpoint,
    this.initialResponse,
  });

  @override
  State<ApiDetailScreen> createState() => _ApiDetailScreenState();
}

class _ApiDetailScreenState extends State<ApiDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  ApiResponse? _response;
  bool _isRunning = false;
  int _selectedRespTab = 0; // 0=JSON, 1=Headers, 2=Raw

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _response = widget.initialResponse;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _isRunning = true;
      _response = null;
    });
    final provider = context.read<ApiProvider>();
    final response = await provider.run(widget.endpoint);
    if (mounted) {
      setState(() {
        _response = response;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.endpoint.name, style: const TextStyle(fontSize: 15)),
            Text(
              widget.endpoint.fullUrl,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppTheme.bgSecondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Request'),
            Tab(text: 'Response'),
            Tab(text: 'Headers'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? null : _run,
        backgroundColor: _isRunning ? AppTheme.bgTertiary : AppTheme.accent,
        icon: _isRunning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow, color: Colors.white),
        label: Text(
          _isRunning ? 'Running...' : 'Run',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _RequestTab(endpoint: widget.endpoint),
          _ResponseTab(response: _response, isRunning: _isRunning),
          _RequestHeadersTab(endpoint: widget.endpoint),
        ],
      ),
    );
  }
}

// ── Request Tab ───────────────────────────────────────────────────────────────

class _RequestTab extends StatelessWidget {
  final ApiEndpoint endpoint;
  const _RequestTab({required this.endpoint});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow(
          label: 'Method',
          value: endpoint.method.label,
          valueColor: endpoint.method.label.methodColor,
        ),
        _InfoRow(label: 'Base URL', value: endpoint.baseUrl),
        _InfoRow(label: 'Path', value: endpoint.path, mono: true),
        _InfoRow(label: 'Group', value: endpoint.groupName),
        if (endpoint.description.isNotEmpty)
          _InfoRow(label: 'Description', value: endpoint.description),
        if (endpoint.body.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'REQUEST BODY',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 8),
          _CodeBlock(code: _prettyJson(endpoint.body)),
        ],
      ],
    );
  }

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

// ── Request Headers Tab ───────────────────────────────────────────────────────

class _RequestHeadersTab extends StatelessWidget {
  final ApiEndpoint endpoint;
  const _RequestHeadersTab({required this.endpoint});

  @override
  Widget build(BuildContext context) {
    if (endpoint.headers.isEmpty) {
      return const EmptyState(
        emoji: '📋',
        title: 'Không có headers',
        subtitle: 'Endpoint này không có headers',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: endpoint.headers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final h = endpoint.headers[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: h.enabled
                      ? AppTheme.statusOnline
                      : AppTheme.statusOffline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.key,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      h.value,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
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

// ── Response Tab ──────────────────────────────────────────────────────────────

class _ResponseTab extends StatefulWidget {
  final ApiResponse? response;
  final bool isRunning;
  const _ResponseTab({this.response, required this.isRunning});

  @override
  State<_ResponseTab> createState() => _ResponseTabState();
}

class _ResponseTabState extends State<_ResponseTab> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.isRunning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            SizedBox(height: 12),
            Text(
              'Đang gọi API...',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (widget.response == null) {
      return const EmptyState(
        emoji: '▶',
        title: 'Nhấn Run để gọi API',
        subtitle: 'Kết quả sẽ hiển thị ở đây',
      );
    }

    final r = widget.response!;

    return Column(
      children: [
        // Status bar
        Container(
          color: AppTheme.bgSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatusChip(code: r.statusCode),
              const SizedBox(width: 16),
              _MetaChip(label: 'Time', value: r.durationLabel),
              const SizedBox(width: 8),
              _MetaChip(label: 'Size', value: r.sizeLabel),
              const Spacer(),
              CopyButton(text: r.body, label: 'Copy JSON'),
            ],
          ),
        ),
        const Divider(height: 0),

        // Sub-tabs
        Container(
          color: AppTheme.bgSecondary,
          child: Row(
            children: [
              _SubTab(
                label: 'JSON',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _SubTab(
                label: 'Headers',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
              _SubTab(
                label: 'Raw',
                selected: _tab == 2,
                onTap: () => setState(() => _tab = 2),
              ),
            ],
          ),
        ),
        const Divider(height: 0),

        // Content
        Expanded(
          child: _tab == 0
              ? _JsonView(body: r.body)
              : _tab == 1
              ? _ResponseHeaders(headers: r.headers)
              : _RawView(body: r.body),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int code;
  const _StatusChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final color = code.toString().statusCodeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        code == 0 ? 'ERROR' : '$code ${_statusTextMap[code] ?? ''}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

const _statusTextMap = {
  200: 'OK',
  201: 'Created',
  204: 'No Content',
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  500: 'Server Error',
};

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accent : AppTheme.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final String body;
  const _JsonView({required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _CodeBlock(code: body),
    );
  }
}

class _RawView extends StatelessWidget {
  final String body;
  const _RawView({required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: SelectableText(
        body,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.6,
        ),
      ),
    );
  }
}

class _ResponseHeaders extends StatelessWidget {
  final Map<String, String> headers;
  const _ResponseHeaders({required this.headers});

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const EmptyState(emoji: '📋', title: 'Không có response headers');
    }
    final entries = headers.entries.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              entries[i].key,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entries[i].value,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared code block ─────────────────────────────────────────────────────────

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.7,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
