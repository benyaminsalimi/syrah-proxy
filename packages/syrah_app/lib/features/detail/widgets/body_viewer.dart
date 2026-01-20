import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';

/// Widget for displaying request/response body with format detection
class BodyViewer extends StatefulWidget {
  final dynamic body;
  final String? contentType;

  const BodyViewer({
    super.key,
    required this.body,
    this.contentType,
  });

  @override
  State<BodyViewer> createState() => _BodyViewerState();
}

class _BodyViewerState extends State<BodyViewer> {
  bool _showRaw = false;
  bool _wordWrap = true;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (widget.body == null || widget.body.toString().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.code_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No body content',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final bodyType = _detectBodyType();

    return Column(
      children: [
        _buildToolbar(context, bodyType),
        const Divider(height: 1),
        Expanded(
          child: _buildBodyContent(bodyType),
        ),
      ],
    );
  }

  _BodyType _detectBodyType() {
    final content = widget.body.toString();

    // Check if it's binary data
    if (widget.body is Uint8List) {
      return _BodyType.binary;
    }

    // Try to detect JSON
    if (content.trimLeft().startsWith('{') || content.trimLeft().startsWith('[')) {
      try {
        json.decode(content);
        return _BodyType.json;
      } catch (_) {}
    }

    // Check for XML/HTML
    if (content.trimLeft().startsWith('<')) {
      if (content.contains('<!DOCTYPE html') || content.contains('<html')) {
        return _BodyType.html;
      }
      return _BodyType.xml;
    }

    // Check content type header
    final contentType = widget.contentType?.toLowerCase() ?? '';
    if (contentType.contains('json')) return _BodyType.json;
    if (contentType.contains('xml')) return _BodyType.xml;
    if (contentType.contains('html')) return _BodyType.html;
    if (contentType.contains('image')) return _BodyType.image;

    return _BodyType.text;
  }

  Widget _buildToolbar(BuildContext context, _BodyType bodyType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Format indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getBodyTypeColor(bodyType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              bodyType.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getBodyTypeColor(bodyType),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Size indicator
          Text(
            _formatSize(widget.body.toString().length),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const Spacer(),
          // Search
          if (bodyType != _BodyType.image && bodyType != _BodyType.binary)
            SizedBox(
              width: 150,
              height: 28,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 14),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          const SizedBox(width: 8),
          // View mode toggle
          if (bodyType == _BodyType.json)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Parsed', style: TextStyle(fontSize: 10))),
                ButtonSegment(value: true, label: Text('Raw', style: TextStyle(fontSize: 10))),
              ],
              selected: {_showRaw},
              onSelectionChanged: (v) => setState(() => _showRaw = v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const SizedBox(width: 8),
          // Word wrap toggle
          IconButton(
            icon: Icon(
              _wordWrap ? Icons.wrap_text : Icons.notes,
              size: 16,
            ),
            onPressed: () => setState(() => _wordWrap = !_wordWrap),
            tooltip: _wordWrap ? 'Disable word wrap' : 'Enable word wrap',
            visualDensity: VisualDensity.compact,
          ),
          // Copy button
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: _copyBody,
            tooltip: 'Copy body',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(_BodyType bodyType) {
    switch (bodyType) {
      case _BodyType.json:
        return _showRaw ? _buildRawView() : _buildJsonView();
      case _BodyType.xml:
      case _BodyType.html:
        return _buildSyntaxView();
      case _BodyType.image:
        return _buildImageView();
      case _BodyType.binary:
        return _buildHexView();
      case _BodyType.text:
        return _buildRawView();
    }
  }

  Widget _buildJsonView() {
    try {
      final decoded = json.decode(widget.body.toString());
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _JsonTreeView(
          data: decoded,
          searchQuery: _searchQuery,
        ),
      );
    } catch (e) {
      return _buildRawView();
    }
  }

  Widget _buildRawView() {
    final content = widget.body.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        _wordWrap ? content : content,
        style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
      ),
    );
  }

  Widget _buildSyntaxView() {
    // Basic syntax highlighting for XML/HTML
    final content = widget.body.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText.rich(
        _highlightXml(content),
        style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
      ),
    );
  }

  Widget _buildImageView() {
    // Try to display the image
    try {
      final bytes = widget.body is Uint8List
          ? widget.body as Uint8List
          : Uint8List.fromList(widget.body.toString().codeUnits);
      return Center(
        child: InteractiveViewer(
          child: Image.memory(bytes),
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, size: 48),
            const SizedBox(height: 8),
            Text('Failed to load image: $e'),
          ],
        ),
      );
    }
  }

  Widget _buildHexView() {
    final bytes = widget.body is Uint8List
        ? widget.body as Uint8List
        : Uint8List.fromList(widget.body.toString().codeUnits);

    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i += 16) {
      // Address
      buffer.write(i.toRadixString(16).padLeft(8, '0'));
      buffer.write('  ');

      // Hex bytes
      for (var j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          buffer.write(bytes[i + j].toRadixString(16).padLeft(2, '0'));
          buffer.write(' ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) buffer.write(' ');
      }

      buffer.write(' |');

      // ASCII
      for (var j = 0; j < 16 && i + j < bytes.length; j++) {
        final byte = bytes[i + j];
        buffer.write(byte >= 32 && byte < 127 ? String.fromCharCode(byte) : '.');
      }

      buffer.write('|\n');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        buffer.toString(),
        style: Theme.of(context).textTheme.code.copyWith(fontSize: 11),
      ),
    );
  }

  TextSpan _highlightXml(String content) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(<[^>]+>)|([^<]+)');

    for (final match in regex.allMatches(content)) {
      if (match.group(1) != null) {
        // Tag
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(color: AppColors.info),
        ));
      } else {
        // Content
        spans.add(TextSpan(text: match.group(2)));
      }
    }

    return TextSpan(children: spans);
  }

  Color _getBodyTypeColor(_BodyType type) {
    switch (type) {
      case _BodyType.json:
        return AppColors.success;
      case _BodyType.xml:
        return AppColors.warning;
      case _BodyType.html:
        return AppColors.info;
      case _BodyType.image:
        return AppColors.methodPatch;
      case _BodyType.binary:
        return AppColors.textSecondaryLight;
      case _BodyType.text:
        return AppColors.textSecondaryLight;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _copyBody() {
    Clipboard.setData(ClipboardData(text: widget.body.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Body copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// Body content type enum
enum _BodyType {
  json('JSON'),
  xml('XML'),
  html('HTML'),
  image('Image'),
  binary('Binary'),
  text('Text');

  final String displayName;
  const _BodyType(this.displayName);
}

/// JSON tree view widget
class _JsonTreeView extends StatelessWidget {
  final dynamic data;
  final String searchQuery;
  final int depth;

  const _JsonTreeView({
    required this.data,
    this.searchQuery = '',
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      return _buildMap(context, data as Map);
    } else if (data is List) {
      return _buildList(context, data as List);
    } else {
      return _buildValue(context, data);
    }
  }

  Widget _buildMap(BuildContext context, Map map) {
    if (map.isEmpty) {
      return const Text(
        '{}',
        style: TextStyle(color: AppColors.textSecondaryLight),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in map.entries)
          _JsonNode(
            nodeKey: entry.key.toString(),
            value: entry.value,
            searchQuery: searchQuery,
            depth: depth,
          ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List list) {
    if (list.isEmpty) {
      return const Text(
        '[]',
        style: TextStyle(color: AppColors.textSecondaryLight),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < list.length; i++)
          _JsonNode(
            nodeKey: '[$i]',
            value: list[i],
            searchQuery: searchQuery,
            depth: depth,
            isArrayItem: true,
          ),
      ],
    );
  }

  Widget _buildValue(BuildContext context, dynamic value) {
    return SelectableText(
      value?.toString() ?? 'null',
      style: TextStyle(
        color: _getValueColor(value),
        fontFamily: 'SF Mono',
        fontSize: 12,
      ),
    );
  }

  Color _getValueColor(dynamic value) {
    if (value == null) return AppColors.textSecondaryLight;
    if (value is bool) return AppColors.warning;
    if (value is num) return AppColors.info;
    if (value is String) return AppColors.success;
    return AppColors.textPrimaryLight;
  }
}

/// Single JSON tree node
class _JsonNode extends StatefulWidget {
  final String nodeKey;
  final dynamic value;
  final String searchQuery;
  final int depth;
  final bool isArrayItem;

  const _JsonNode({
    required this.nodeKey,
    required this.value,
    this.searchQuery = '',
    this.depth = 0,
    this.isArrayItem = false,
  });

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  bool _isExpanded = true;

  bool get _isExpandable => widget.value is Map || widget.value is List;

  bool get _hasChildren {
    if (widget.value is Map) return (widget.value as Map).isNotEmpty;
    if (widget.value is List) return (widget.value as List).isNotEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isMatch = widget.searchQuery.isNotEmpty &&
        (widget.nodeKey.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
            widget.value.toString().toLowerCase().contains(widget.searchQuery.toLowerCase()));

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _isExpandable ? () => setState(() => _isExpanded = !_isExpanded) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: isMatch ? AppColors.warning.withOpacity(0.2) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isExpandable)
                    Icon(
                      _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    )
                  else
                    const SizedBox(width: 16),
                  Text(
                    widget.nodeKey,
                    style: TextStyle(
                      color: widget.isArrayItem
                          ? AppColors.textSecondaryLight
                          : AppColors.methodDelete,
                      fontFamily: 'SF Mono',
                      fontSize: 12,
                    ),
                  ),
                  const Text(': ', style: TextStyle(fontFamily: 'SF Mono', fontSize: 12)),
                  if (!_isExpandable)
                    Expanded(child: _buildValue())
                  else if (!_isExpanded)
                    Text(
                      widget.value is Map
                          ? '{...} (${(widget.value as Map).length})'
                          : '[...] (${(widget.value as List).length})',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontFamily: 'SF Mono',
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded && _isExpandable)
            _JsonTreeView(
              data: widget.value,
              searchQuery: widget.searchQuery,
              depth: widget.depth + 1,
            ),
        ],
      ),
    );
  }

  Widget _buildValue() {
    final value = widget.value;
    String text;
    Color color;

    if (value == null) {
      text = 'null';
      color = AppColors.textSecondaryLight;
    } else if (value is bool) {
      text = value.toString();
      color = AppColors.warning;
    } else if (value is num) {
      text = value.toString();
      color = AppColors.info;
    } else if (value is String) {
      text = '"$value"';
      color = AppColors.success;
    } else {
      text = value.toString();
      color = AppColors.textPrimaryLight;
    }

    return SelectableText(
      text,
      style: TextStyle(
        color: color,
        fontFamily: 'SF Mono',
        fontSize: 12,
      ),
    );
  }
}
