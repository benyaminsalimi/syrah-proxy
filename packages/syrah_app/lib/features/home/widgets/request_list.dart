import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syrah_core/models/models.dart';

import '../../../app/theme/app_theme.dart';
import '../home_controller.dart';

/// List of captured HTTP requests with column headers
class RequestList extends ConsumerStatefulWidget {
  const RequestList({super.key});

  @override
  ConsumerState<RequestList> createState() => _RequestListState();
}

class _RequestListState extends ConsumerState<RequestList> {
  // Column widths (adjustable)
  double _starWidth = 24;
  double _methodWidth = 65;
  double _statusWidth = 50;
  double _hostWidth = 150;
  double _durationWidth = 70;
  double _sizeWidth = 70;
  // Path takes remaining space (Expanded)

  @override
  Widget build(BuildContext context) {
    final flows = ref.watch(filteredFlowsProvider);
    final selectedFlow = ref.watch(selectedFlowProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Column headers
        _buildColumnHeaders(isDark),
        const Divider(height: 1),
        // Request list
        Expanded(
          child: flows.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  itemCount: flows.length,
                  itemBuilder: (context, index) {
                    final flow = flows[index];
                    final isSelected = selectedFlow?.id == flow.id;
                    return _RequestListItem(
                      flow: flow,
                      isSelected: isSelected,
                      onTap: () => ref.read(homeControllerProvider.notifier).selectFlow(flow),
                      starWidth: _starWidth,
                      methodWidth: _methodWidth,
                      statusWidth: _statusWidth,
                      hostWidth: _hostWidth,
                      durationWidth: _durationWidth,
                      sizeWidth: _sizeWidth,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildColumnHeaders(bool isDark) {
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    );

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      child: Row(
        children: [
          // Star column
          _buildResizableHeader('', _starWidth, (delta) {
            setState(() => _starWidth = (_starWidth + delta).clamp(20.0, 40.0));
          }, headerStyle, alignment: Alignment.center),
          // Method column
          _buildResizableHeader('Method', _methodWidth, (delta) {
            setState(() => _methodWidth = (_methodWidth + delta).clamp(50.0, 100.0));
          }, headerStyle, alignment: Alignment.center),
          // Status column
          _buildResizableHeader('Status', _statusWidth, (delta) {
            setState(() => _statusWidth = (_statusWidth + delta).clamp(40.0, 80.0));
          }, headerStyle, alignment: Alignment.center),
          // Host column
          _buildResizableHeader('Host', _hostWidth, (delta) {
            setState(() => _hostWidth = (_hostWidth + delta).clamp(80.0, 300.0));
          }, headerStyle),
          // Path column (flexible)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Path', style: headerStyle),
            ),
          ),
          // Duration column
          _buildResizableHeader('Time', _durationWidth, (delta) {
            setState(() => _durationWidth = (_durationWidth + delta).clamp(50.0, 120.0));
          }, headerStyle, alignment: Alignment.centerRight),
          // Size column
          _buildResizableHeader('Size', _sizeWidth, (delta) {
            setState(() => _sizeWidth = (_sizeWidth + delta).clamp(50.0, 120.0));
          }, headerStyle, alignment: Alignment.centerRight, showDivider: false),
        ],
      ),
    );
  }

  Widget _buildResizableHeader(
    String title,
    double width,
    Function(double) onResize,
    TextStyle style, {
    Alignment alignment = Alignment.centerLeft,
    bool showDivider = true,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: alignment,
              child: Text(title, style: style),
            ),
          ),
          if (showDivider)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) => onResize(details.delta.dx),
                child: Container(
                  width: 8,
                  height: 28,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 1,
                      height: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single request list item
class _RequestListItem extends StatelessWidget {
  final NetworkFlow flow;
  final bool isSelected;
  final VoidCallback onTap;
  final double starWidth;
  final double methodWidth;
  final double statusWidth;
  final double hostWidth;
  final double durationWidth;
  final double sizeWidth;

  const _RequestListItem({
    required this.flow,
    required this.isSelected,
    required this.onTap,
    required this.starWidth,
    required this.methodWidth,
    required this.statusWidth,
    required this.hostWidth,
    required this.durationWidth,
    required this.sizeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final request = flow.request;
    final response = flow.response;

    final method = request.method.name.toUpperCase();
    final host = request.host;
    final path = request.path;
    final statusCode = response?.statusCode;
    final isMarked = flow.isMarked;

    // Use the flow's duration helper
    final duration = flow.formattedDuration;

    // Use the flow's size helper
    final size = flow.formattedSize;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isSelected
        ? (isDark ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.1))
        : null;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Star indicator
              SizedBox(
                width: starWidth,
                child: isMarked
                    ? const Icon(Icons.star, size: 14, color: AppColors.warning)
                    : null,
              ),
              // Method
              SizedBox(
                width: methodWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.methodColor(method).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    method,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.methodColor(method),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Status code
              SizedBox(
                width: statusWidth,
                child: Center(child: _buildStatusIndicator(statusCode, flow.state)),
              ),
              // Host
              SizedBox(
                width: hostWidth,
                child: Text(
                  host,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Path (flexible)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    path,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Duration
              SizedBox(
                width: durationWidth,
                child: Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // Size
              SizedBox(
                width: sizeWidth,
                child: Text(
                  size,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(int? statusCode, FlowState state) {
    if (statusCode != null) {
      return Text(
        statusCode.toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.statusColor(statusCode),
        ),
      );
    }

    // Show state indicator
    switch (state) {
      case FlowState.pending:
      case FlowState.waiting:
      case FlowState.receiving:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case FlowState.failed:
        return const Icon(Icons.error, size: 14, color: AppColors.error);
      case FlowState.paused:
        return const Icon(Icons.pause, size: 14, color: AppColors.warning);
      case FlowState.aborted:
        return const Icon(Icons.cancel, size: 14, color: AppColors.error);
      default:
        return const Text('-', style: TextStyle(fontSize: 12));
    }
  }
}

/// Empty state when no requests captured
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No requests captured',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the proxy and configure your device\nto capture network traffic',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
