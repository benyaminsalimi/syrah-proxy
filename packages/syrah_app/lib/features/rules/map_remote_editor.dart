import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'rules_controller.dart';

/// Dialog for creating/editing Map Remote rules
class MapRemoteEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final Function(Map<String, dynamic>) onSave;

  const MapRemoteEditorDialog({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<MapRemoteEditorDialog> createState() => _MapRemoteEditorDialogState();
}

class _MapRemoteEditorDialogState extends State<MapRemoteEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _sourcePatternController;
  late TextEditingController _targetUrlController;
  late bool _isEnabled;
  late bool _preservePath;
  late bool _preserveQuery;
  late bool _preserveHeaders;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?['name'] as String? ?? '');
    _sourcePatternController =
        TextEditingController(text: rule?['urlPattern'] as String? ?? '*');
    _targetUrlController =
        TextEditingController(text: rule?['targetUrl'] as String? ?? '');
    _isEnabled = rule?['isEnabled'] as bool? ?? true;
    _preservePath = rule?['preservePath'] as bool? ?? true;
    _preserveQuery = rule?['preserveQuery'] as bool? ?? true;
    _preserveHeaders = rule?['preserveHeaders'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sourcePatternController.dispose();
    _targetUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Map Remote Rule' : 'New Map Remote Rule'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Map Remote redirects matching requests to a different URL.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My Remote Rule',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Source section
              const _SectionLabel(
                label: 'Source',
                icon: Icons.arrow_forward,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sourcePatternController,
                decoration: const InputDecoration(
                  labelText: 'Source URL Pattern',
                  hintText: 'https://api.example.com/*',
                  helperText: 'Use * as wildcard, or /regex/ for regex patterns',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Target section
              const _SectionLabel(
                label: 'Target',
                icon: Icons.arrow_back,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetUrlController,
                decoration: const InputDecoration(
                  labelText: 'Target URL',
                  hintText: 'https://staging.example.com',
                  helperText: 'The URL to redirect requests to',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Options
              const _SectionLabel(
                label: 'Options',
                icon: Icons.settings,
              ),
              const SizedBox(height: 8),

              CheckboxListTile(
                title: const Text('Preserve path'),
                subtitle: const Text('Append original path to target URL'),
                value: _preservePath,
                onChanged: (value) =>
                    setState(() => _preservePath = value ?? true),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              CheckboxListTile(
                title: const Text('Preserve query parameters'),
                subtitle: const Text('Include original query string'),
                value: _preserveQuery,
                onChanged: (value) =>
                    setState(() => _preserveQuery = value ?? true),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              CheckboxListTile(
                title: const Text('Preserve headers'),
                subtitle: const Text('Forward original request headers'),
                value: _preserveHeaders,
                onChanged: (value) =>
                    setState(() => _preserveHeaders = value ?? true),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              const Divider(),

              SwitchListTile(
                title: const Text('Enabled'),
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
                contentPadding: EdgeInsets.zero,
              ),

              // Preview
              if (_sourcePatternController.text.isNotEmpty &&
                  _targetUrlController.text.isNotEmpty)
                _buildPreview(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave() ? _save : null,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _sourcePatternController.text,
                  style: Theme.of(context).textTheme.code.copyWith(
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _targetUrlController.text + (_preservePath ? '/...' : ''),
                  style: Theme.of(context).textTheme.code.copyWith(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    return _nameController.text.isNotEmpty &&
        _sourcePatternController.text.isNotEmpty &&
        _targetUrlController.text.isNotEmpty;
  }

  void _save() {
    final rule = {
      if (widget.rule != null) 'id': widget.rule!['id'],
      'type': RuleType.mapRemote.name,
      'name': _nameController.text,
      'urlPattern': _sourcePatternController.text,
      'targetUrl': _targetUrlController.text,
      'isEnabled': _isEnabled,
      'preservePath': _preservePath,
      'preserveQuery': _preserveQuery,
      'preserveHeaders': _preserveHeaders,
    };
    widget.onSave(rule);
    Navigator.pop(context);
  }
}

/// Section label widget
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
