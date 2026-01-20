import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import 'breakpoint_controller.dart';

/// Dialog shown when a breakpoint is hit
class BreakpointHitDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> flow;
  final Map<String, dynamic> breakpoint;
  final bool isRequest;

  const BreakpointHitDialog({
    super.key,
    required this.flow,
    required this.breakpoint,
    required this.isRequest,
  });

  @override
  ConsumerState<BreakpointHitDialog> createState() => _BreakpointHitDialogState();
}

class _BreakpointHitDialogState extends ConsumerState<BreakpointHitDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _modifiedFlow;
  late TextEditingController _urlController;
  late TextEditingController _methodController;
  late TextEditingController _headersController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _modifiedFlow = Map<String, dynamic>.from(widget.flow);

    final data = widget.isRequest
        ? widget.flow['request'] as Map<String, dynamic>? ?? {}
        : widget.flow['response'] as Map<String, dynamic>? ?? {};

    _urlController = TextEditingController(text: data['url'] as String? ?? '');
    _methodController =
        TextEditingController(text: data['method'] as String? ?? 'GET');

    // Format headers as editable text
    final headers = data['headers'] as Map<String, dynamic>? ?? {};
    final headerLines = headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    _headersController = TextEditingController(text: headerLines);

    // Format body
    final body = data['body'];
    String bodyText = '';
    if (body != null) {
      if (body is Map || body is List) {
        bodyText = const JsonEncoder.withIndent('  ').convert(body);
      } else {
        bodyText = body.toString();
      }
    }
    _bodyController = TextEditingController(text: bodyText);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _methodController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breakpointName = widget.breakpoint['name'] as String? ?? 'Breakpoint';

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.pause_circle_filled,
              color: AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakpoint Hit',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '$breakpointName - ${widget.isRequest ? 'Request' : 'Response'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 500,
        child: Column(
          children: [
            // Summary bar
            _buildSummaryBar(context),
            const SizedBox(height: 12),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: widget.isRequest ? 'URL & Method' : 'Status'),
                  const Tab(text: 'Headers'),
                  const Tab(text: 'Body'),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUrlMethodTab(),
                  _buildHeadersTab(),
                  _buildBodyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Abort button
        TextButton.icon(
          onPressed: _abort,
          icon: const Icon(Icons.block, color: AppColors.error),
          label: const Text(
            'Abort',
            style: TextStyle(color: AppColors.error),
          ),
        ),
        const Spacer(),
        // Cancel (don't modify)
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        // Resume without changes
        OutlinedButton.icon(
          onPressed: _resumeUnmodified,
          icon: const Icon(Icons.skip_next),
          label: const Text('Resume'),
        ),
        const SizedBox(width: 8),
        // Resume with changes
        FilledButton.icon(
          onPressed: _resumeModified,
          icon: const Icon(Icons.send),
          label: const Text('Resume Modified'),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(BuildContext context) {
    final data = widget.isRequest
        ? widget.flow['request'] as Map<String, dynamic>? ?? {}
        : widget.flow['response'] as Map<String, dynamic>? ?? {};

    final method = data['method'] as String? ?? 'GET';
    final url = data['url'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.methodColor(method).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              method,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.methodColor(method),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlMethodTab() {
    if (widget.isRequest) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Method selector
            DropdownButtonFormField<String>(
              value: _methodController.text,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'GET', child: Text('GET')),
                DropdownMenuItem(value: 'POST', child: Text('POST')),
                DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
                DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                DropdownMenuItem(value: 'HEAD', child: Text('HEAD')),
                DropdownMenuItem(value: 'OPTIONS', child: Text('OPTIONS')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _methodController.text = value;
                }
              },
            ),
            const SizedBox(height: 16),
            // URL field
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      );
    } else {
      // Response - show status code
      final response = widget.flow['response'] as Map<String, dynamic>? ?? {};
      final statusCode = response['statusCode'] as int? ?? 200;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: statusCode.toString(),
              decoration: const InputDecoration(
                labelText: 'Status Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: response['statusMessage'] as String? ?? '',
              decoration: const InputDecoration(
                labelText: 'Status Message',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHeadersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit headers (one per line, format: Header-Name: value)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _headersController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Edit body content',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _formatJson,
                icon: const Icon(Icons.format_align_left, size: 16),
                label: const Text('Format JSON'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _formatJson() {
    try {
      final decoded = json.decode(_bodyController.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      _bodyController.text = formatted;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid JSON'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Map<String, String> _parseHeaders() {
    final headers = <String, String>{};
    final lines = _headersController.text.split('\n');
    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final name = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        headers[name] = value;
      }
    }
    return headers;
  }

  void _abort() {
    ref.read(breakpointControllerProvider.notifier).abortFlow();
    Navigator.pop(context);
  }

  void _resumeUnmodified() {
    ref.read(breakpointControllerProvider.notifier).resumeFlow(null);
    Navigator.pop(context);
  }

  void _resumeModified() {
    final key = widget.isRequest ? 'request' : 'response';
    final currentData =
        Map<String, dynamic>.from(_modifiedFlow[key] as Map<String, dynamic>? ?? {});

    if (widget.isRequest) {
      currentData['method'] = _methodController.text;
      currentData['url'] = _urlController.text;
    }
    currentData['headers'] = _parseHeaders();

    // Try to parse body as JSON, fall back to string
    try {
      currentData['body'] = json.decode(_bodyController.text);
    } catch (_) {
      currentData['body'] = _bodyController.text;
    }

    _modifiedFlow[key] = currentData;

    ref.read(breakpointControllerProvider.notifier).resumeFlow(_modifiedFlow);
    Navigator.pop(context);
  }
}
