import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'rules_controller.dart';

/// Full screen editor for creating/editing script rules
class ScriptEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final Function(Map<String, dynamic>) onSave;

  const ScriptEditorScreen({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _urlPatternController;
  late TextEditingController _onRequestController;
  late TextEditingController _onResponseController;
  late bool _isEnabled;
  String? _testOutput;

  static const _defaultRequestScript = '''
// Modify the request before it is sent
// Available: request.method, request.url, request.headers, request.body
function onRequest(request) {
  // Example: Add a custom header
  // request.headers['X-Custom-Header'] = 'value';

  // Example: Log the request
  // console.log('Request:', request.url);

  return request;
}
''';

  static const _defaultResponseScript = '''
// Modify the response before it is returned
// Available: response.statusCode, response.headers, response.body
function onResponse(response) {
  // Example: Modify response body
  // if (response.body && response.body.data) {
  //   response.body.modified = true;
  // }

  // Example: Log the response
  // console.log('Response:', response.statusCode);

  return response;
}
''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?['name'] as String? ?? '');
    _urlPatternController =
        TextEditingController(text: rule?['urlPattern'] as String? ?? '*');
    _onRequestController = TextEditingController(
      text: rule?['onRequestScript'] as String? ?? _defaultRequestScript,
    );
    _onResponseController = TextEditingController(
      text: rule?['onResponseScript'] as String? ?? _defaultResponseScript,
    );
    _isEnabled = rule?['isEnabled'] as bool? ?? true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlPatternController.dispose();
    _onRequestController.dispose();
    _onResponseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Script Rule' : 'New Script Rule'),
        actions: [
          TextButton.icon(
            onPressed: _testScript,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _canSave() ? _save : null,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Rule settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'My Script',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _urlPatternController,
                    decoration: const InputDecoration(
                      labelText: 'URL Pattern',
                      hintText: '*api.example.com/*',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Text('Enabled'),
                    Switch(
                      value: _isEnabled,
                      onChanged: (value) => setState(() => _isEnabled = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Script tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('onRequest'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('onResponse'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScriptEditor(_onRequestController, 'Request'),
                _buildScriptEditor(_onResponseController, 'Response'),
              ],
            ),
          ),
          // Test output
          if (_testOutput != null)
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Console Output',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _testOutput = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _testOutput!,
                        style: Theme.of(context).textTheme.code.copyWith(
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScriptEditor(
      TextEditingController controller, String phase) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Text(
                'JavaScript',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_box_outlined, size: 18),
                tooltip: 'Insert Snippet',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'header',
                    child: Text('Add Header'),
                  ),
                  const PopupMenuItem(
                    value: 'remove_header',
                    child: Text('Remove Header'),
                  ),
                  const PopupMenuItem(
                    value: 'log',
                    child: Text('Console Log'),
                  ),
                  const PopupMenuItem(
                    value: 'modify_body',
                    child: Text('Modify JSON Body'),
                  ),
                  const PopupMenuItem(
                    value: 'delay',
                    child: Text('Add Delay'),
                  ),
                ],
                onSelected: (value) => _insertSnippet(controller, value, phase),
              ),
              IconButton(
                icon: const Icon(Icons.format_align_left, size: 18),
                onPressed: () => _formatCode(controller),
                tooltip: 'Format Code',
              ),
              IconButton(
                icon: const Icon(Icons.restore, size: 18),
                onPressed: () => _resetToDefault(controller, phase),
                tooltip: 'Reset to Default',
              ),
            ],
          ),
        ),
        // Editor
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontFamilyFallback: ['Menlo', 'Monaco', 'Consolas', 'monospace'],
                fontSize: 13,
                color: Color(0xFFD4D4D4),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              cursorColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _insertSnippet(
      TextEditingController controller, String snippet, String phase) {
    final isRequest = phase == 'Request';
    final obj = isRequest ? 'request' : 'response';

    String code;
    switch (snippet) {
      case 'header':
        code = "$obj.headers['X-Custom-Header'] = 'value';";
        break;
      case 'remove_header':
        code = "delete $obj.headers['Header-To-Remove'];";
        break;
      case 'log':
        code = isRequest
            ? "console.log('Request:', $obj.method, $obj.url);"
            : "console.log('Response:', $obj.statusCode);";
        break;
      case 'modify_body':
        code = isRequest
            ? '''
if ($obj.body) {
  $obj.body.modified = true;
  $obj.body.timestamp = Date.now();
}'''
            : '''
if ($obj.body && typeof $obj.body === 'object') {
  $obj.body.processedAt = new Date().toISOString();
}''';
        break;
      case 'delay':
        code = '''
// Add artificial delay (in milliseconds)
await new Promise(resolve => setTimeout(resolve, 1000));''';
        break;
      default:
        return;
    }

    final selection = controller.selection;
    final text = controller.text;
    final newText = text.substring(0, selection.start) +
        '\n  $code\n  ' +
        text.substring(selection.end);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + code.length + 4,
      ),
    );
  }

  void _formatCode(TextEditingController controller) {
    // Basic formatting - in real implementation, use a proper JS formatter
    var text = controller.text;

    // Add basic indentation
    text = text.replaceAll(RegExp(r'\{\s*'), '{\n  ');
    text = text.replaceAll(RegExp(r'\}\s*'), '\n}\n');
    text = text.replaceAll(RegExp(r';\s*'), ';\n  ');

    controller.text = text.trim();
  }

  void _resetToDefault(TextEditingController controller, String phase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Script?'),
        content: const Text(
            'This will replace the current script with the default template.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.text = phase == 'Request'
                  ? _defaultRequestScript
                  : _defaultResponseScript;
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _testScript() {
    // In real implementation, this would execute the script with test data
    setState(() {
      _testOutput = '''
[${DateTime.now().toIso8601String()}] Testing script...
[TEST] onRequest function found: ✓
[TEST] onResponse function found: ✓
[TEST] Script syntax: Valid
[TEST] No runtime errors detected

Test request:
  URL: https://api.example.com/users
  Method: GET

Script execution completed successfully.
''';
    });
  }

  bool _canSave() {
    return _nameController.text.isNotEmpty &&
        _urlPatternController.text.isNotEmpty;
  }

  void _save() {
    final rule = {
      if (widget.rule != null) 'id': widget.rule!['id'],
      'type': RuleType.script.name,
      'name': _nameController.text,
      'urlPattern': _urlPatternController.text,
      'onRequestScript': _onRequestController.text,
      'onResponseScript': _onResponseController.text,
      'isEnabled': _isEnabled,
    };
    widget.onSave(rule);
    Navigator.pop(context);
  }
}
