import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';

/// Widget for displaying HTTP headers in a table format
class HeadersView extends StatefulWidget {
  final Map<String, String> headers;

  const HeadersView({super.key, required this.headers});

  @override
  State<HeadersView> createState() => _HeadersViewState();
}

class _HeadersViewState extends State<HeadersView> {
  String _searchQuery = '';
  bool _showRaw = false;

  Map<String, String> get _filteredHeaders {
    if (_searchQuery.isEmpty) return widget.headers;
    final query = _searchQuery.toLowerCase();
    return Map.fromEntries(
      widget.headers.entries.where((e) =>
          e.key.toLowerCase().contains(query) ||
          e.value.toLowerCase().contains(query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.headers.isEmpty) {
      return Center(
        child: Text(
          'No headers',
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: _showRaw ? _buildRawView() : _buildTableView(),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filter headers...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Table', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: true, label: Text('Raw', style: TextStyle(fontSize: 11))),
            ],
            selected: {_showRaw},
            onSelectionChanged: (v) => setState(() => _showRaw = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: _copyHeaders,
            tooltip: 'Copy all headers',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    final headers = _filteredHeaders;

    return ListView.builder(
      itemCount: headers.length,
      itemBuilder: (context, index) {
        final entry = headers.entries.elementAt(index);
        return _HeaderRow(
          name: entry.key,
          value: entry.value.toString(),
          isEven: index.isEven,
        );
      },
    );
  }

  Widget _buildRawView() {
    final buffer = StringBuffer();
    for (final entry in widget.headers.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        buffer.toString(),
        style: Theme.of(context).textTheme.code,
      ),
    );
  }

  void _copyHeaders() {
    final buffer = StringBuffer();
    for (final entry in widget.headers.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Headers copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// Single header row widget
class _HeaderRow extends StatelessWidget {
  final String name;
  final String value;
  final bool isEven;

  const _HeaderRow({
    required this.name,
    required this.value,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _showHeaderDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isEven
            ? Colors.transparent
            : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: SelectableText(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getHeaderColor(name),
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: () => _copyValue(context),
              tooltip: 'Copy value',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Color _getHeaderColor(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('content-')) return AppColors.info;
    if (lower.startsWith('x-')) return AppColors.warning;
    if (lower.contains('auth') || lower.contains('cookie')) return AppColors.error;
    if (lower.startsWith('cache-') || lower == 'etag') return AppColors.success;
    return AppColors.textSecondaryLight;
  }

  void _copyValue(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $name'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showHeaderDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name, style: const TextStyle(fontSize: 14)),
        content: SelectableText(
          value,
          style: Theme.of(context).textTheme.code,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$name: $value'));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
