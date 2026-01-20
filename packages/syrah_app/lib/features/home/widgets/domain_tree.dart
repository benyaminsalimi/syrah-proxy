import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syrah_core/models/models.dart';

import '../home_controller.dart';

/// Tree view grouping requests by domain
class DomainTree extends ConsumerWidget {
  const DomainTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flows = ref.watch(homeControllerProvider).flows;

    // Group flows by host
    final groups = <String, List<NetworkFlow>>{};
    for (final flow in flows) {
      final host = flow.request.host;
      groups.putIfAbsent(host, () => []).add(flow);
    }

    if (groups.isEmpty) {
      return const Center(
        child: Text(
          'No domains',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Sort hosts by request count
    final sortedHosts = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    return ListView.builder(
      itemCount: sortedHosts.length,
      itemBuilder: (context, index) {
        final host = sortedHosts[index];
        final hostFlows = groups[host]!;

        return _DomainTreeItem(
          host: host,
          flows: hostFlows,
        );
      },
    );
  }
}

/// Single domain tree item
class _DomainTreeItem extends ConsumerStatefulWidget {
  final String host;
  final List<NetworkFlow> flows;

  const _DomainTreeItem({
    required this.host,
    required this.flows,
  });

  @override
  ConsumerState<_DomainTreeItem> createState() => _DomainTreeItemState();
}

class _DomainTreeItemState extends ConsumerState<_DomainTreeItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Group by path prefix
    final pathGroups = <String, List<NetworkFlow>>{};
    for (final flow in widget.flows) {
      final path = flow.request.path;
      final pathPrefix = _getPathPrefix(path);
      pathGroups.putIfAbsent(pathPrefix, () => []).add(flow);
    }

    final hasError = widget.flows.any((f) {
      final statusCode = f.response?.statusCode;
      return statusCode != null && statusCode >= 400;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                ),
                const SizedBox(width: 4),
                if (hasError)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.host,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.flows.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ...pathGroups.entries.map((entry) => _PathGroupItem(
                pathPrefix: entry.key,
                flows: entry.value,
                host: widget.host,
              )),
      ],
    );
  }

  String _getPathPrefix(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '/';
    return '/${segments.first}';
  }
}

/// Path group item within a domain
class _PathGroupItem extends ConsumerWidget {
  final String pathPrefix;
  final List<NetworkFlow> flows;
  final String host;

  const _PathGroupItem({
    required this.pathPrefix,
    required this.flows,
    required this.host,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: InkWell(
        onTap: () {
          // Filter to show only flows for this path
          // This would typically update a filter state
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pathPrefix,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${flows.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
