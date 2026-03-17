import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/api_provider.dart';
import '../../models/api_endpoint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ApiFormScreen extends StatefulWidget {
  final ApiEndpoint? endpoint;
  const ApiFormScreen({super.key, this.endpoint});

  @override
  State<ApiFormScreen> createState() => _ApiFormScreenState();
}

class _ApiFormScreenState extends State<ApiFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _groupCtrl;
  late HttpMethod _method;
  late List<_HeaderEntry> _headers;
  bool _isSaving = false;

  bool get _isEdit => widget.endpoint != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final e = widget.endpoint;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _baseUrlCtrl = TextEditingController(text: e?.baseUrl ?? 'https://');
    _pathCtrl = TextEditingController(text: e?.path ?? '/');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    _groupCtrl = TextEditingController(text: e?.groupName ?? 'Default');
    _method = e?.method ?? HttpMethod.GET;
    _headers =
        (e?.headers ??
                [
                  const ApiHeader(
                    key: 'Content-Type',
                    value: 'application/json',
                  ),
                ])
            .map(
              (h) => _HeaderEntry(
                keyCtrl: TextEditingController(text: h.key),
                valueCtrl: TextEditingController(text: h.value),
                enabled: h.enabled,
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _pathCtrl.dispose();
    _descCtrl.dispose();
    _bodyCtrl.dispose();
    _groupCtrl.dispose();
    for (final h in _headers) {
      h.keyCtrl.dispose();
      h.valueCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _tabCtrl.animateTo(0);
      return;
    }
    setState(() => _isSaving = true);

    final headers = _headers
        .where((h) => h.keyCtrl.text.isNotEmpty)
        .map(
          (h) => ApiHeader(
            key: h.keyCtrl.text.trim(),
            value: h.valueCtrl.text.trim(),
            enabled: h.enabled,
          ),
        )
        .toList();

    final endpoint = ApiEndpoint(
      id: widget.endpoint?.id ?? '',
      name: _nameCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim().replaceAll(RegExp(r'/$'), ''),
      path: _pathCtrl.text.trim(),
      method: _method,
      description: _descCtrl.text.trim(),
      headers: headers,
      body: _bodyCtrl.text.trim(),
      groupName: _groupCtrl.text.trim().isEmpty
          ? 'Default'
          : _groupCtrl.text.trim(),
      createdAt: widget.endpoint?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<ApiProvider>();
    if (_isEdit) {
      await provider.update(endpoint);
    } else {
      await provider.add(endpoint);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa Endpoint' : 'Thêm Endpoint'),
        backgroundColor: AppTheme.bgSecondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : ElevatedButton(
                    onPressed: _save,
                    child: Text(_isEdit ? 'Lưu' : 'Thêm'),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Cơ bản'),
            Tab(text: 'Headers'),
            Tab(text: 'Body'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _BasicTab(
              nameCtrl: _nameCtrl,
              baseUrlCtrl: _baseUrlCtrl,
              pathCtrl: _pathCtrl,
              descCtrl: _descCtrl,
              groupCtrl: _groupCtrl,
              method: _method,
              onMethodChanged: (m) => setState(() => _method = m),
            ),
            _HeadersTab(
              headers: _headers,
              onAdd: () => setState(() {
                _headers.add(
                  _HeaderEntry(
                    keyCtrl: TextEditingController(),
                    valueCtrl: TextEditingController(),
                  ),
                );
              }),
              onRemove: (i) => setState(() => _headers.removeAt(i)),
              onToggle: (i) =>
                  setState(() => _headers[i].enabled = !_headers[i].enabled),
            ),
            _BodyTab(bodyCtrl: _bodyCtrl, method: _method),
          ],
        ),
      ),
    );
  }
}

// ── Basic Tab ─────────────────────────────────────────────────────────────────

class _BasicTab extends StatelessWidget {
  final TextEditingController nameCtrl,
      baseUrlCtrl,
      pathCtrl,
      descCtrl,
      groupCtrl;
  final HttpMethod method;
  final ValueChanged<HttpMethod> onMethodChanged;

  const _BasicTab({
    required this.nameCtrl,
    required this.baseUrlCtrl,
    required this.pathCtrl,
    required this.descCtrl,
    required this.groupCtrl,
    required this.method,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Label('Tên endpoint *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: nameCtrl,
          validator: (v) => v?.isEmpty == true ? 'Bắt buộc' : null,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: const InputDecoration(hintText: 'Get All Users'),
        ),
        const SizedBox(height: 14),

        // Method + path row
        _Label('Method & Path *'),
        const SizedBox(height: 6),
        Row(
          children: [
            // Method dropdown
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<HttpMethod>(
                  value: method,
                  dropdownColor: AppTheme.bgSecondary,
                  items: HttpMethod.values
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.label,
                            style: TextStyle(
                              color: m.label.methodColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (m) {
                    if (m != null) onMethodChanged(m);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: pathCtrl,
                validator: (v) => v?.isEmpty == true ? 'Bắt buộc' : null,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(hintText: '/api/v1/users'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _Label('Base URL *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: baseUrlCtrl,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Bắt buộc';
            if (!v.startsWith('http')) return 'Phải bắt đầu bằng http';
            return null;
          },
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://api.mycompany.com',
          ),
        ),
        const SizedBox(height: 14),

        _Label('Group / Folder'),
        const SizedBox(height: 6),
        TextFormField(
          controller: groupCtrl,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: const InputDecoration(hintText: 'Users'),
        ),
        const SizedBox(height: 14),

        _Label('Mô tả'),
        const SizedBox(height: 6),
        TextFormField(
          controller: descCtrl,
          maxLines: 2,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Fetch paginated user list',
          ),
        ),
      ],
    );
  }
}

// ── Headers Tab ───────────────────────────────────────────────────────────────

class _HeadersTab extends StatelessWidget {
  final List<_HeaderEntry> headers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onToggle;

  const _HeadersTab({
    required this.headers,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: headers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final h = headers[i];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onToggle(i),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: h.enabled
                              ? AppTheme.methodGetBg
                              : AppTheme.bgTertiary,
                          border: Border.all(
                            color: h.enabled
                                ? AppTheme.methodGet
                                : AppTheme.border,
                            width: 1,
                          ),
                        ),
                        child: h.enabled
                            ? const Icon(
                                Icons.check,
                                size: 10,
                                color: AppTheme.methodGet,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: h.keyCtrl,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Key',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Container(width: 0.5, height: 24, color: AppTheme.border),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: h.valueCtrl,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Value',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemove(i),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Thêm header'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentLight,
                side: const BorderSide(color: AppTheme.border, width: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Body Tab ──────────────────────────────────────────────────────────────────

class _BodyTab extends StatelessWidget {
  final TextEditingController bodyCtrl;
  final HttpMethod method;

  const _BodyTab({required this.bodyCtrl, required this.method});

  @override
  Widget build(BuildContext context) {
    if (method == HttpMethod.GET || method == HttpMethod.DELETE) {
      return const Center(
        child: EmptyState(
          emoji: '📭',
          title: 'Không có request body',
          subtitle: 'GET và DELETE không có body',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('JSON Body'),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: TextField(
                controller: bodyCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.7,
                ),
                decoration: const InputDecoration(
                  hintText: '{\n  "key": "value"\n}',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04,
      ),
    );
  }
}

class _HeaderEntry {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  bool enabled;

  _HeaderEntry({
    required this.keyCtrl,
    required this.valueCtrl,
    this.enabled = true,
  });
}
