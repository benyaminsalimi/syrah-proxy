import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';

/// Screen for comparing two requests/responses side by side
class DiffScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? leftFlow;
  final Map<String, dynamic>? rightFlow;

  const DiffScreen({
    super.key,
    this.leftFlow,
    this.rightFlow,
  });

  @override
  ConsumerState<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends ConsumerState<DiffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _leftFlow;
  Map<String, dynamic>? _rightFlow;
  _DiffViewMode _viewMode = _DiffViewMode.sideBySide;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _leftFlow = widget.leftFlow;
    _rightFlow = widget.rightFlow;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Requests'),
        actions: [
          // View mode toggle
          SegmentedButton<_DiffViewMode>(
            segments: const [
              ButtonSegment(
                value: _DiffViewMode.sideBySide,
                icon: Icon(Icons.view_column, size: 18),
                tooltip: 'Side by Side',
              ),
              ButtonSegment(
                value: _DiffViewMode.unified,
                icon: Icon(Icons.view_stream, size: 18),
                tooltip: 'Unified',
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (v) => setState(() => _viewMode = v.first),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Headers'),
            Tab(text: 'Body'),
          ],
        ),
      ),
      body: _leftFlow == null || _rightFlow == null
          ? _buildSelectionState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewDiff(),
                _buildHeadersDiff(),
                _buildBodyDiff(),
              ],
            ),
    );
  }

  Widget _buildSelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Select two requests to compare',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose requests from the request list\nto compare their headers and body',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewDiff() {
    final leftRequest = _leftFlow?['request'] as Map<String, dynamic>?;
    final rightRequest = _rightFlow?['request'] as Map<String, dynamic>?;
    final leftResponse = _leftFlow?['response'] as Map<String, dynamic>?;
    final rightResponse = _rightFlow?['response'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonRow(
            'URL',
            leftRequest?['url'] as String? ?? '',
            rightRequest?['url'] as String? ?? '',
          ),
          const Divider(),
          _buildComparisonRow(
            'Method',
            leftRequest?['method'] as String? ?? '',
            rightRequest?['method'] as String? ?? '',
          ),
          const Divider(),
          _buildComparisonRow(
            'Status',
            (leftResponse?['statusCode'] as int?)?.toString() ?? '-',
            (rightResponse?['statusCode'] as int?)?.toString() ?? '-',
          ),
          const Divider(),
          _buildComparisonRow(
            'Content-Type',
            _getHeader(leftResponse, 'content-type'),
            _getHeader(rightResponse, 'content-type'),
          ),
          const Divider(),
          _buildComparisonRow(
            'Content-Length',
            _getHeader(leftResponse, 'content-length'),
            _getHeader(rightResponse, 'content-length'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersDiff() {
    final leftHeaders =
        _leftFlow?['response']?['headers'] as Map<String, dynamic>? ?? {};
    final rightHeaders =
        _rightFlow?['response']?['headers'] as Map<String, dynamic>? ?? {};

    final allKeys = {...leftHeaders.keys, ...rightHeaders.keys}.toList()..sort();

    if (_viewMode == _DiffViewMode.sideBySide) {
      return Row(
        children: [
          Expanded(
            child: _buildHeadersList(leftHeaders, rightHeaders, true),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildHeadersList(rightHeaders, leftHeaders, false),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: allKeys.length,
      itemBuilder: (context, index) {
        final key = allKeys[index];
        final leftValue = leftHeaders[key]?.toString();
        final rightValue = rightHeaders[key]?.toString();
        final isDifferent = leftValue != rightValue;

        return _UnifiedDiffRow(
          header: key,
          leftValue: leftValue,
          rightValue: rightValue,
          isDifferent: isDifferent,
        );
      },
    );
  }

  Widget _buildHeadersList(
    Map<String, dynamic> headers,
    Map<String, dynamic> otherHeaders,
    bool isLeft,
  ) {
    final entries = headers.entries.toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: Text(
            isLeft ? 'Left' : 'Right',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final otherValue = otherHeaders[entry.key]?.toString();
              final isDifferent = entry.value.toString() != otherValue;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: isDifferent
                    ? (isLeft
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1))
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDifferent
                            ? (isLeft ? AppColors.error : AppColors.success)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value.toString(),
                      style: Theme.of(context).textTheme.code.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBodyDiff() {
    final leftBody = _leftFlow?['response']?['body'];
    final rightBody = _rightFlow?['response']?['body'];

    final leftText = _formatBody(leftBody);
    final rightText = _formatBody(rightBody);

    if (_viewMode == _DiffViewMode.sideBySide) {
      return Row(
        children: [
          Expanded(
            child: _buildBodyPane(leftText, 'Left', true),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildBodyPane(rightText, 'Right', false),
          ),
        ],
      );
    }

    return _buildUnifiedBodyDiff(leftText, rightText);
  }

  Widget _buildBodyPane(String text, String label, bool isLeft) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedBodyDiff(String leftText, String rightText) {
    final leftLines = leftText.split('\n');
    final rightLines = rightText.split('\n');
    final maxLines =
        leftLines.length > rightLines.length ? leftLines.length : rightLines.length;

    return ListView.builder(
      itemCount: maxLines,
      itemBuilder: (context, index) {
        final leftLine = index < leftLines.length ? leftLines[index] : null;
        final rightLine = index < rightLines.length ? rightLines[index] : null;
        final isDifferent = leftLine != rightLine;

        if (!isDifferent) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    leftLine ?? '',
                    style: Theme.of(context).textTheme.code.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (leftLine != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                color: AppColors.error.withOpacity(0.1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '-${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        leftLine,
                        style: Theme.of(context).textTheme.code.copyWith(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (rightLine != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                color: AppColors.success.withOpacity(0.1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '+${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rightLine,
                        style: Theme.of(context).textTheme.code.copyWith(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildComparisonRow(String label, String left, String right) {
    final isDifferent = left != right;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDifferent
                        ? AppColors.error.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    left.isEmpty ? '-' : left,
                    style: Theme.of(context).textTheme.code.copyWith(
                          fontSize: 11,
                          color: isDifferent ? AppColors.error : null,
                        ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  isDifferent ? Icons.not_equal : Icons.check,
                  size: 16,
                  color: isDifferent ? AppColors.error : AppColors.success,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDifferent
                        ? AppColors.success.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    right.isEmpty ? '-' : right,
                    style: Theme.of(context).textTheme.code.copyWith(
                          fontSize: 11,
                          color: isDifferent ? AppColors.success : null,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getHeader(Map<String, dynamic>? response, String name) {
    if (response == null) return '-';
    final headers = response['headers'] as Map<String, dynamic>? ?? {};
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value.toString();
      }
    }
    return '-';
  }

  String _formatBody(dynamic body) {
    if (body == null) return '';
    if (body is Map || body is List) {
      return const JsonEncoder.withIndent('  ').convert(body);
    }
    return body.toString();
  }
}

enum _DiffViewMode { sideBySide, unified }

/// Unified diff row widget
class _UnifiedDiffRow extends StatelessWidget {
  final String header;
  final String? leftValue;
  final String? rightValue;
  final bool isDifferent;

  const _UnifiedDiffRow({
    required this.header,
    this.leftValue,
    this.rightValue,
    required this.isDifferent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                header,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (isDifferent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Different',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isDifferent) ...[
            const SizedBox(height: 8),
            if (leftValue != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '- ',
                      style: TextStyle(color: AppColors.error),
                    ),
                    Expanded(
                      child: Text(
                        leftValue!,
                        style: Theme.of(context).textTheme.code.copyWith(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            if (rightValue != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '+ ',
                      style: TextStyle(color: AppColors.success),
                    ),
                    Expanded(
                      child: Text(
                        rightValue!,
                        style: Theme.of(context).textTheme.code.copyWith(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              leftValue ?? rightValue ?? '',
              style: Theme.of(context).textTheme.code.copyWith(
                    fontSize: 11,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
