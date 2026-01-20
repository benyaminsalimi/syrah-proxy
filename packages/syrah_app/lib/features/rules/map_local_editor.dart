import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'rules_controller.dart';

/// Dialog for creating/editing Map Local rules
class MapLocalEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final Function(Map<String, dynamic>) onSave;

  const MapLocalEditorDialog({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<MapLocalEditorDialog> createState() => _MapLocalEditorDialogState();
}

class _MapLocalEditorDialogState extends State<MapLocalEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlPatternController;
  late TextEditingController _localPathController;
  late TextEditingController _statusCodeController;
  late TextEditingController _contentTypeController;
  late bool _isEnabled;
  late bool _preserveMethod;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?['name'] as String? ?? '');
    _urlPatternController =
        TextEditingController(text: rule?['urlPattern'] as String? ?? '*');
    _localPathController =
        TextEditingController(text: rule?['localPath'] as String? ?? '');
    _statusCodeController = TextEditingController(
        text: (rule?['statusCode'] as int?)?.toString() ?? '200');
    _contentTypeController = TextEditingController(
        text: rule?['contentType'] as String? ?? 'application/json');
    _isEnabled = rule?['isEnabled'] as bool? ?? true;
    _preserveMethod = rule?['preserveMethod'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlPatternController.dispose();
    _localPathController.dispose();
    _statusCodeController.dispose();
    _contentTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Map Local Rule' : 'New Map Local Rule'),
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
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 20, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Map Local returns a local file as the response for matching requests.',
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
                  hintText: 'My Local Rule',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // URL Pattern
              TextField(
                controller: _urlPatternController,
                decoration: const InputDecoration(
                  labelText: 'URL Pattern',
                  hintText: '*api.example.com/users*',
                  helperText:
                      'Use * as wildcard, or /regex/ for regex patterns',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Local File Path
              TextField(
                controller: _localPathController,
                decoration: InputDecoration(
                  labelText: 'Local File Path',
                  hintText: '/path/to/response.json',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _pickFile,
                    tooltip: 'Browse...',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Response settings
              const Text(
                'Response Settings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _statusCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Status Code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _contentTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Content-Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Options
              CheckboxListTile(
                title: const Text('Preserve original HTTP method'),
                subtitle: const Text(
                    'If disabled, all methods will receive the local file'),
                value: _preserveMethod,
                onChanged: (value) =>
                    setState(() => _preserveMethod = value ?? true),
                contentPadding: EdgeInsets.zero,
              ),

              SwitchListTile(
                title: const Text('Enabled'),
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
                contentPadding: EdgeInsets.zero,
              ),
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

  bool _canSave() {
    return _nameController.text.isNotEmpty &&
        _urlPatternController.text.isNotEmpty &&
        _localPathController.text.isNotEmpty;
  }

  void _pickFile() async {
    // In a real implementation, this would open a file picker
    // For now, we'll just show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker would open here'),
      ),
    );
  }

  void _save() {
    final rule = {
      if (widget.rule != null) 'id': widget.rule!['id'],
      'type': RuleType.mapLocal.name,
      'name': _nameController.text,
      'urlPattern': _urlPatternController.text,
      'localPath': _localPathController.text,
      'statusCode': int.tryParse(_statusCodeController.text) ?? 200,
      'contentType': _contentTypeController.text,
      'isEnabled': _isEnabled,
      'preserveMethod': _preserveMethod,
    };
    widget.onSave(rule);
    Navigator.pop(context);
  }
}
