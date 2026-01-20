import 'package:flutter/material.dart';
import 'package:syrah_core/models/models.dart';

import '../../../app/theme/app_theme.dart';

/// Touch-friendly mobile list item for network requests
class RequestListItemMobile extends StatelessWidget {
  final NetworkFlow flow;
  final bool isSelected;
  final VoidCallback onTap;

  const RequestListItemMobile({
    super.key,
    required this.flow,
    required this.isSelected,
    required this.onTap,
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

    // Format display path - truncate if too long
    final displayPath = path.length > 60 ? '${path.substring(0, 60)}...' : path;

    // Use the flow's duration helper
    final duration = flow.formattedDuration;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isSelected
        ? (isDark
            ? AppColors.primary.withOpacity(0.3)
            : AppColors.primary.withOpacity(0.1))
        : null;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Star indicator
              if (isMarked)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.star,
                    size: 16,
                    color: AppColors.warning,
                  ),
                ),
              // Method badge
              _MethodBadge(method: method),
              const SizedBox(width: 12),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Host with status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            host,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusIndicator(statusCode, flow.state),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Path
                    Text(
                      displayPath,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    // Duration and size
                    Row(
                      children: [
                        if (duration.isNotEmpty) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (flow.formattedSize.isNotEmpty) ...[
                          Icon(
                            Icons.data_usage_outlined,
                            size: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            flow.formattedSize,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron indicator
              Icon(
                Icons.chevron_right,
                size: 24,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(int? statusCode, FlowState state) {
    if (statusCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusColor(statusCode).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          statusCode.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.statusColor(statusCode),
          ),
        ),
      );
    }

    // Show state indicator
    switch (state) {
      case FlowState.pending:
      case FlowState.waiting:
      case FlowState.receiving:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case FlowState.failed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, size: 12, color: AppColors.error),
              SizedBox(width: 4),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      case FlowState.paused:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause, size: 12, color: AppColors.warning),
              SizedBox(width: 4),
              Text(
                'Paused',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );
      case FlowState.aborted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel, size: 12, color: AppColors.error),
              SizedBox(width: 4),
              Text(
                'Aborted',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Method badge widget
class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.methodColor(method).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.methodColor(method),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
