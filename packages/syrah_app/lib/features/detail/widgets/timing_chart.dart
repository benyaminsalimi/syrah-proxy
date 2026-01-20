import 'package:flutter/material.dart';
import 'package:syrah_core/models/models.dart';

import '../../../app/theme/app_theme.dart';

/// Widget for displaying request/response timing breakdown
class TimingChart extends StatelessWidget {
  final NetworkFlow flow;

  const TimingChart({super.key, required this.flow});

  @override
  Widget build(BuildContext context) {
    final request = flow.request;
    final response = flow.response;

    final requestTimestamp = request.timestamp;
    final responseTimestamp = response?.timestamp;

    if (responseTimestamp == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Timing data not available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final totalDuration = responseTimestamp.difference(requestTimestamp).inMilliseconds;

    // Simulated timing breakdown - in real implementation,
    // these would come from actual timing data
    final timings = _calculateTimings(totalDuration);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(context, totalDuration, requestTimestamp, responseTimestamp),
          const SizedBox(height: 24),
          _buildWaterfallChart(context, timings, totalDuration),
          const SizedBox(height: 24),
          _buildTimingDetails(context, timings),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, int totalDuration, DateTime requestTime, DateTime responseTime) {
    return Row(
      children: [
        _SummaryCard(
          label: 'Total Time',
          value: _formatDuration(totalDuration),
          icon: Icons.timer_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          label: 'Started',
          value: _formatTimestamp(requestTime),
          icon: Icons.schedule,
          color: AppColors.success,
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          label: 'Completed',
          value: _formatTimestamp(responseTime),
          icon: Icons.check_circle_outline,
          color: AppColors.info,
        ),
      ],
    );
  }

  Widget _buildWaterfallChart(
    BuildContext context,
    Map<String, int> timings,
    int totalDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Waterfall',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth - 120; // Label width

            return Column(
              children: timings.entries.map((entry) {
                final percentage = totalDuration > 0
                    ? entry.value / totalDuration
                    : 0.0;
                final barWidth = (maxWidth * percentage).clamp(2.0, maxWidth);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              height: 20,
                              width: barWidth,
                              decoration: BoxDecoration(
                                color: _getTimingColor(entry.key),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _formatDuration(entry.value),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimingDetails(BuildContext context, Map<String, int> timings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timing Breakdown',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < timings.entries.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TimingRow(
                  label: timings.entries.elementAt(i).key,
                  value: timings.entries.elementAt(i).value,
                  description: _getTimingDescription(timings.entries.elementAt(i).key),
                  color: _getTimingColor(timings.entries.elementAt(i).key),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Map<String, int> _calculateTimings(int totalDuration) {
    // In a real implementation, these would come from actual timing data
    // This is a simulated breakdown
    if (totalDuration <= 0) {
      return {
        'DNS Lookup': 0,
        'TCP Connection': 0,
        'TLS Handshake': 0,
        'Time to First Byte': 0,
        'Content Download': 0,
      };
    }

    final dns = (totalDuration * 0.05).round().clamp(1, totalDuration ~/ 5);
    final tcp = (totalDuration * 0.10).round().clamp(1, totalDuration ~/ 4);
    final ssl = (totalDuration * 0.15).round().clamp(1, totalDuration ~/ 3);
    final ttfb = (totalDuration * 0.30).round().clamp(1, totalDuration ~/ 2);
    final download = totalDuration - dns - tcp - ssl - ttfb;

    return {
      'DNS Lookup': dns,
      'TCP Connection': tcp,
      'TLS Handshake': ssl,
      'Time to First Byte': ttfb,
      'Content Download': download.clamp(1, totalDuration),
    };
  }

  Color _getTimingColor(String phase) {
    switch (phase) {
      case 'DNS Lookup':
        return const Color(0xFF8E44AD);
      case 'TCP Connection':
        return const Color(0xFFE67E22);
      case 'TLS Handshake':
        return const Color(0xFF9B59B6);
      case 'Time to First Byte':
        return const Color(0xFF3498DB);
      case 'Content Download':
        return const Color(0xFF2ECC71);
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _getTimingDescription(String phase) {
    switch (phase) {
      case 'DNS Lookup':
        return 'Time to resolve the domain name to an IP address';
      case 'TCP Connection':
        return 'Time to establish a TCP connection to the server';
      case 'TLS Handshake':
        return 'Time to complete the TLS/SSL handshake';
      case 'Time to First Byte':
        return 'Time from sending the request to receiving the first byte';
      case 'Content Download':
        return 'Time to download the full response body';
      default:
        return '';
    }
  }

  String _formatDuration(int ms) {
    if (ms < 1) return '<1ms';
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(2)}s';
    return '${(ms / 60000).toStringAsFixed(1)}min';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timing row in the breakdown table
class _TimingRow extends StatelessWidget {
  final String label;
  final int value;
  final String description;
  final Color color;

  const _TimingRow({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
  });

  String get _formattedValue {
    if (value < 1) return '<1ms';
    if (value < 1000) return '${value}ms';
    return '${(value / 1000).toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formattedValue,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Mono',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
