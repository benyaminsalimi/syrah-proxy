import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Dialog for creating/editing breakpoint rules
class BreakpointEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? breakpoint;
  final Function(Map<String, dynamic>) onSave;

  const BreakpointEditorDialog({
    super.key,
    this.breakpoint,
    required this.onSave,
  });

  @override
  State<BreakpointEditorDialog> createState() => _BreakpointEditorDialogState();
}

class _BreakpointEditorDialogState extends State<BreakpointEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlPatternController;
  late bool _breakOnRequest;
  late bool _breakOnResponse;
  late bool _isEnabled;
  late Set<String> _selectedMethods;

  static const _httpMethods = [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS'
  ];

  @override
  void initState() {
    super.initState();
    final bp = widget.breakpoint;
    _nameController = TextEditingController(text: bp?['name'] as String? ?? '');
    _urlPatternController =
        TextEditingController(text: bp?['urlPattern'] as String? ?? '*');
    _breakOnRequest = bp?['breakOnRequest'] as bool? ?? true;
    _breakOnResponse = bp?['breakOnResponse'] as bool? ?? false;
    _isEnabled = bp?['isEnabled'] as bool? ?? true;
    _selectedMethods = Set<String>.from(
      (bp?['methods'] as List<dynamic>?) ?? _httpMethods,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlPatternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.breakpoint != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Breakpoint' : 'New Breakpoint'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My Breakpoint',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // URL Pattern
              TextField(
                controller: _urlPatternController,
                decoration: const InputDecoration(
                  labelText: 'URL Pattern',
                  hintText: '*api.example.com/*',
                  helperText: 'Use * as wildcard. Example: *api.example.com/users*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Break on Request/Response
              const Text(
                'Break on',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _BreakOptionCard(
                      title: 'Request',
                      subtitle: 'Pause before request is sent',
                      icon: Icons.upload_outlined,
                      color: AppColors.methodPost,
                      isSelected: _breakOnRequest,
                      onTap: () => setState(() => _breakOnRequest = !_breakOnRequest),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BreakOptionCard(
                      title: 'Response',
                      subtitle: 'Pause before response is received',
                      icon: Icons.download_outlined,
                      color: AppColors.methodGet,
                      isSelected: _breakOnResponse,
                      onTap: () => setState(() => _breakOnResponse = !_breakOnResponse),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // HTTP Methods
              const Text(
                'HTTP Methods',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _httpMethods.map((method) {
                  final isSelected = _selectedMethods.contains(method);
                  return FilterChip(
                    label: Text(
                      method,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.methodColor(method),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMethods.add(method);
                        } else {
                          _selectedMethods.remove(method);
                        }
                      });
                    },
                    selectedColor: AppColors.methodColor(method),
                    checkmarkColor: Colors.white,
                    backgroundColor: AppColors.methodColor(method).withOpacity(0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedMethods = Set.from(_httpMethods)),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedMethods.clear()),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Enabled toggle
              SwitchListTile(
                title: const Text('Enabled'),
                subtitle: const Text('Activate this breakpoint'),
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
        (_breakOnRequest || _breakOnResponse) &&
        _selectedMethods.isNotEmpty;
  }

  void _save() {
    final breakpoint = {
      if (widget.breakpoint != null) 'id': widget.breakpoint!['id'],
      'name': _nameController.text,
      'urlPattern': _urlPatternController.text,
      'breakOnRequest': _breakOnRequest,
      'breakOnResponse': _breakOnResponse,
      'isEnabled': _isEnabled,
      'methods': _selectedMethods.toList(),
    };
    widget.onSave(breakpoint);
    Navigator.pop(context);
  }
}

/// Option card for break type selection
class _BreakOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _BreakOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? color : Theme.of(context).colorScheme.outline,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 18, color: color)
                else
                  Icon(
                    Icons.radio_button_unchecked,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
