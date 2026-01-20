import 'dart:async';

import '../models/models.dart';

/// Service for managing network flows
class FlowService {
  final _flowController = StreamController<NetworkFlow>.broadcast();
  final _flowListController = StreamController<List<NetworkFlow>>.broadcast();

  final List<NetworkFlow> _flows = [];
  final Map<String, NetworkFlow> _flowsById = {};

  /// Stream of individual flow updates
  Stream<NetworkFlow> get flowStream => _flowController.stream;

  /// Stream of complete flow list updates
  Stream<List<NetworkFlow>> get flowListStream => _flowListController.stream;

  /// Get all flows
  List<NetworkFlow> get flows => List.unmodifiable(_flows);

  /// Get a flow by ID
  NetworkFlow? getFlow(String id) => _flowsById[id];

  /// Add a new flow
  void addFlow(NetworkFlow flow) {
    _flows.add(flow);
    _flowsById[flow.id] = flow;
    _flowController.add(flow);
    _flowListController.add(flows);
  }

  /// Update an existing flow
  void updateFlow(NetworkFlow flow) {
    final index = _flows.indexWhere((f) => f.id == flow.id);
    if (index != -1) {
      _flows[index] = flow;
      _flowsById[flow.id] = flow;
      _flowController.add(flow);
      _flowListController.add(flows);
    }
  }

  /// Remove a flow
  void removeFlow(String id) {
    _flows.removeWhere((f) => f.id == id);
    _flowsById.remove(id);
    _flowListController.add(flows);
  }

  /// Clear all flows
  void clearFlows() {
    _flows.clear();
    _flowsById.clear();
    _flowListController.add(flows);
  }

  /// Get flows matching a filter
  List<NetworkFlow> getFilteredFlows(FilterState filter) {
    if (!filter.hasActiveFilter) return flows;
    return flows.where((f) => filter.matches(f)).toList();
  }

  /// Group flows by host
  Map<String, List<NetworkFlow>> groupByHost() {
    final groups = <String, List<NetworkFlow>>{};
    for (final flow in _flows) {
      final host = flow.request.host;
      groups.putIfAbsent(host, () => []).add(flow);
    }
    return groups;
  }

  /// Group flows by domain tree
  List<FlowGroup> groupByDomainTree() {
    final hostGroups = groupByHost();
    final groups = <FlowGroup>[];

    for (final entry in hostGroups.entries) {
      final pathGroups = <String, List<NetworkFlow>>{};
      for (final flow in entry.value) {
        final path = flow.groupPath;
        pathGroups.putIfAbsent(path, () => []).add(flow);
      }

      final subgroups = pathGroups.entries.map((e) => FlowGroup(
            key: e.key,
            displayName: e.key,
            flows: e.value,
          )).toList();

      groups.add(FlowGroup(
        key: entry.key,
        displayName: entry.key,
        subgroups: subgroups,
      ));
    }

    return groups;
  }

  /// Mark a flow as starred/marked
  void toggleMark(String id) {
    final flow = _flowsById[id];
    if (flow != null) {
      updateFlow(flow.copyWith(isMarked: !flow.isMarked));
    }
  }

  /// Add a tag to a flow
  void addTag(String id, String tag) {
    final flow = _flowsById[id];
    if (flow != null && !flow.tags.contains(tag)) {
      updateFlow(flow.copyWith(tags: [...flow.tags, tag]));
    }
  }

  /// Remove a tag from a flow
  void removeTag(String id, String tag) {
    final flow = _flowsById[id];
    if (flow != null) {
      updateFlow(flow.copyWith(tags: flow.tags.where((t) => t != tag).toList()));
    }
  }

  /// Add notes to a flow
  void setNotes(String id, String? notes) {
    final flow = _flowsById[id];
    if (flow != null) {
      updateFlow(flow.copyWith(notes: notes));
    }
  }

  /// Get statistics for current flows
  FlowStatistics getStatistics() {
    int successCount = 0;
    int errorCount = 0;
    int pendingCount = 0;
    int totalSize = 0;
    Duration totalDuration = Duration.zero;
    int durationCount = 0;

    for (final flow in _flows) {
      if (flow.state == FlowState.completed) {
        if (flow.response?.isSuccess ?? false) {
          successCount++;
        } else if (flow.response?.isError ?? false) {
          errorCount++;
        }
      } else if (flow.isInProgress) {
        pendingCount++;
      } else if (flow.state == FlowState.failed) {
        errorCount++;
      }

      totalSize += flow.totalSize;

      final duration = flow.duration;
      if (duration != null) {
        totalDuration += duration;
        durationCount++;
      }
    }

    return FlowStatistics(
      totalCount: _flows.length,
      successCount: successCount,
      errorCount: errorCount,
      pendingCount: pendingCount,
      totalSize: totalSize,
      averageDuration: durationCount > 0
          ? Duration(
              microseconds: totalDuration.inMicroseconds ~/ durationCount)
          : Duration.zero,
    );
  }

  /// Dispose of resources
  void dispose() {
    _flowController.close();
    _flowListController.close();
  }
}

/// Statistics about captured flows
class FlowStatistics {
  final int totalCount;
  final int successCount;
  final int errorCount;
  final int pendingCount;
  final int totalSize;
  final Duration averageDuration;

  const FlowStatistics({
    required this.totalCount,
    required this.successCount,
    required this.errorCount,
    required this.pendingCount,
    required this.totalSize,
    required this.averageDuration,
  });

  String get formattedTotalSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedAverageDuration {
    final ms = averageDuration.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(2)}s';
  }
}
