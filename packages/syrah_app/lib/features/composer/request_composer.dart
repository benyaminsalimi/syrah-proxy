import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syrah_core/models/models.dart';

import '../../app/theme/app_theme.dart';

/// Request composer for editing and resending requests
class RequestComposer extends ConsumerStatefulWidget {
  final NetworkFlow? initialFlow;

  const RequestComposer({super.key, this.initialFlow});

  @override
  ConsumerState<RequestComposer> createState() => _RequestComposerState();
}

class _RequestComposerState extends ConsumerState<RequestComposer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Request fields
  String _method = 'GET';
  final _urlController = TextEditingController();
  final _headersController = TextEditingController();
  final _bodyController = TextEditingController();

  // Response
  bool _isLoading = false;
  String? _responseStatus;
  String? _responseHeaders;
  String? _responseBody;
  String? _error;
  Duration? _duration;

  final List<String> _methods = [
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
    _tabController = TabController(length: 2, vsync: this);

    // Initialize from existing flow if provided
    if (widget.initialFlow != null) {
      final req = widget.initialFlow!.request;
      _method = req.method.name.toUpperCase();
      _urlController.text = req.url;

      // Format headers (exclude Content-Length as it's auto-calculated)
      final headerLines = <String>[];
      req.headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-length') {
          headerLines.add('$key: $value');
        }
      });
      _headersController.text = headerLines.join('\n');

      // Set body if present
      if (req.bodyText != null) {
        _bodyController.text = req.bodyText!;
      }
    } else {
      // Default headers for new request
      _headersController.text = '''Content-Type: application/json
Accept: application/json
User-Agent: Syrah/1.0''';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Composer'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isLoading ? null : _sendRequest,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(_isLoading ? 'Sending...' : 'Send'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // URL Bar
          _buildUrlBar(),
          const Divider(height: 1),
          // Tabs for Request/Response
          Expanded(
            child: Row(
              children: [
                // Request panel
                Expanded(
                  child: _buildRequestPanel(),
                ),
                const VerticalDivider(width: 1),
                // Response panel
                Expanded(
                  child: _buildResponsePanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Method dropdown
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _method,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                borderRadius: BorderRadius.circular(6),
                items: _methods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(
                      method,
                      style: TextStyle(
                        color: AppColors.methodColor(method),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _method = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // URL input
          Expanded(
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g., https://api.example.com/endpoint)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                prefixIcon: const Icon(Icons.link, size: 18),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.upload, size: 18),
              const SizedBox(width: 8),
              Text(
                'Request',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Headers section
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'Headers',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Content-Length is auto-calculated)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _headersController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Header-Name: value\nAnother-Header: value',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        // Body section
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Body',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: '{\n  "key": "value"\n}',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.download, size: 18),
              const SizedBox(width: 8),
              Text(
                'Response',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (_responseStatus != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _responseStatus!,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_duration != null)
                Text(
                  '${_duration!.inMilliseconds}ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Response content
        Expanded(
          child: _buildResponseContent(),
        ),
      ],
    );
  }

  Widget _buildResponseContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sending request...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Request Failed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      );
    }

    if (_responseBody == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Click Send to make a request',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Body'),
              Tab(text: 'Headers'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Body tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _formatBody(_responseBody!),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                // Headers tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _responseHeaders ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
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

  Color _getStatusColor() {
    if (_responseStatus == null) return Colors.grey;
    final code = int.tryParse(_responseStatus!.split(' ').first) ?? 0;
    return AppColors.statusColor(code);
  }

  String _formatBody(String body) {
    try {
      final json = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return body;
    }
  }

  Map<String, String> _parseHeaders(String headersText) {
    final headers = <String, String>{};
    for (final line in headersText.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        // Skip Content-Length - it will be set automatically based on body
        if (key.isNotEmpty && key.toLowerCase() != 'content-length') {
          headers[key] = value;
        }
      }
    }
    return headers;
  }

  Future<void> _sendRequest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _responseStatus = null;
      _responseHeaders = null;
      _responseBody = null;
      _duration = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);
      final client = HttpClient();

      // Don't verify SSL certificates for debugging
      client.badCertificateCallback = (cert, host, port) => true;

      final request = await client.openUrl(_method, uri);

      // Set headers (Content-Length is excluded and set automatically)
      final headers = _parseHeaders(_headersController.text);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      // Set body for POST/PUT/PATCH
      final bodyText = _bodyController.text;
      if (bodyText.isNotEmpty && ['POST', 'PUT', 'PATCH'].contains(_method)) {
        final bodyBytes = utf8.encode(bodyText);
        request.headers.set('Content-Length', bodyBytes.length.toString());
        request.add(bodyBytes);
      }

      final response = await request.close();
      stopwatch.stop();

      // Read response body
      final responseBody = await response.transform(utf8.decoder).join();

      // Format response headers
      final responseHeaders = StringBuffer();
      response.headers.forEach((name, values) {
        for (final value in values) {
          responseHeaders.writeln('$name: $value');
        }
      });

      setState(() {
        _isLoading = false;
        _responseStatus = '${response.statusCode} ${response.reasonPhrase}';
        _responseHeaders = responseHeaders.toString();
        _responseBody = responseBody;
        _duration = stopwatch.elapsed;
      });

      client.close();
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _duration = stopwatch.elapsed;
      });
    }
  }
}
