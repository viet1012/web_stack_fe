import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/website_provider.dart';
import '../../models/website.dart';
import '../../theme/app_theme.dart';

class WebsiteFormScreen extends StatefulWidget {
  final Website? website;
  const WebsiteFormScreen({super.key, this.website});

  @override
  State<WebsiteFormScreen> createState() => _WebsiteFormScreenState();
}

class _WebsiteFormScreenState extends State<WebsiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagsCtrl;
  late String _emoji;
  bool _isOnline = false;
  bool _isSaving = false;

  bool get _isEdit => widget.website != null;

  final _emojis = ['🌐', '🛒', '📊', '📝', '🧪', '🚀', '🎨', '🔧', '📱', '💼'];

  @override
  void initState() {
    super.initState();
    final w = widget.website;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _urlCtrl = TextEditingController(text: w?.url ?? 'https://');
    _descCtrl = TextEditingController(text: w?.description ?? '');
    _tagsCtrl = TextEditingController(text: w?.tags.join(', ') ?? '');
    _emoji = w?.emoji ?? '🌐';
    _isOnline = w?.isOnline ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final website = Website(
      id: widget.website?.id ?? '',
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      emoji: _emoji,
      tags: tags,
      isOnline: _isOnline,
      createdAt: widget.website?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<WebsiteProvider>();
    if (_isEdit) {
      await provider.update(website);
    } else {
      await provider.add(website);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa Website' : 'Thêm Website'),
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Emoji picker
            _Section(
              title: 'Icon',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? AppTheme.accentBg
                                : AppTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _emoji == e
                                  ? AppTheme.accent
                                  : AppTheme.border,
                              width: _emoji == e ? 1.5 : 0.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            _FormField(
              label: 'Tên website *',
              controller: _nameCtrl,
              hint: 'Shop Online',
              validator: (v) => v?.isEmpty == true ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: 12),

            // URL
            _FormField(
              label: 'URL *',
              controller: _urlCtrl,
              hint: 'https://shop.mycompany.com',
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Bắt buộc';
                if (!v.startsWith('http')) return 'URL phải bắt đầu bằng http';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Description
            _FormField(
              label: 'Mô tả',
              controller: _descCtrl,
              hint: 'E-commerce main site',
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Tags
            _FormField(
              label: 'Tags (phân cách bằng dấu phẩy)',
              controller: _tagsCtrl,
              hint: 'production, flutter.dart',
            ),
            const SizedBox(height: 16),

            // Online toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Text(
                    'Trạng thái online',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isOnline,
                    onChanged: (v) => setState(() => _isOnline = v),
                    activeColor: AppTheme.statusOnline,
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

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
