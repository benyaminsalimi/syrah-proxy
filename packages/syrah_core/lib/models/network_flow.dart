import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

import 'http_request.dart';
import 'http_response.dart';

part 'network_flow.freezed.dart';
part 'network_flow.g.dart';

/// State of a network flow
enum FlowState {
  /// Request is being sent
  pending,

  /// Waiting for response
  waiting,

  /// Response is being received
  receiving,

  /// Flow completed successfully
  completed,

  /// Flow failed with an error
  failed,

  /// Flow was aborted/cancelled
  aborted,

  /// Flow is paused at a breakpoint
  paused,

  /// Flow is being modified
  modifying,
}

/// Protocol type for the flow
enum ProtocolType {
  http,
  https,
  websocket,
  websocketSecure,
}

/// Represents a complete network flow (request + response)
@freezed
class NetworkFlow with _$NetworkFlow {
  const NetworkFlow._();

  const factory NetworkFlow({
    /// Unique identifier for this flow
    required String id,

    /// Session ID this flow belongs to
    required String sessionId,

    /// The HTTP request
    required HttpRequest request,

    /// The HTTP response (null if not received yet)
    HttpResponse? response,

    /// Current state of the flow
    @Default(FlowState.pending) FlowState state,

    /// Protocol type
    @Default(ProtocolType.http) ProtocolType protocol,

    /// WebSocket messages if this is a WebSocket flow
    @Default([]) List<WebSocketMessage> webSocketMessages,

    /// Error message if the flow failed
    String? error,

    /// Tags assigned to this flow
    @Default([]) List<String> tags,

    /// Notes added by user
    String? notes,

    /// Whether this flow is marked/starred
    @Default(false) bool isMarked,

    /// Whether this flow matches current filter
    @Default(true) bool matchesFilter,

    /// Rules that were applied to this flow
    @Default([]) List<String> appliedRules,

    /// Timestamp when flow was created
    required DateTime createdAt,

    /// Timestamp when flow was last updated
    required DateTime updatedAt,

    /// Original request before modification (if modified)
    HttpRequest? originalRequest,

    /// Original response before modification (if modified)
    HttpResponse? originalResponse,

    /// Connection ID for grouping related flows
    String? connectionId,

    /// Sequence number within the session
    @Default(0) int sequenceNumber,
  }) = _NetworkFlow;

  factory NetworkFlow.fromJson(Map<String, dynamic> json) =>
      _$NetworkFlowFromJson(json);

  /// Get the duration of the flow
  Duration? get duration {
    if (response == null) return null;
    return response!.timestamp.difference(request.timestamp);
  }

  /// Get formatted duration string
  String get formattedDuration {
    final d = duration;
    if (d == null) return '-';
    final ms = d.inMilliseconds;
    if (ms < 1000) {
      return '${ms}ms';
    } else {
      return '${(ms / 1000).toStringAsFixed(2)}s';
    }
  }

  /// Get the total size of the flow (request + response)
  int get totalSize {
    int size = request.contentLength;
    if (response != null) {
      size += response!.contentLength;
    }
    return size;
  }

  /// Get formatted size string
  String get formattedSize {
    final bytes = totalSize;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if this is a secure flow
  bool get isSecure =>
      protocol == ProtocolType.https ||
      protocol == ProtocolType.websocketSecure;

  /// Check if this is a WebSocket flow
  bool get isWebSocket =>
      protocol == ProtocolType.websocket ||
      protocol == ProtocolType.websocketSecure;

  /// Check if the flow has been modified
  bool get wasModified => originalRequest != null || originalResponse != null;

  /// Check if the flow is still in progress
  bool get isInProgress =>
      state == FlowState.pending ||
      state == FlowState.waiting ||
      state == FlowState.receiving;

  /// Get the display status code
  String get displayStatus {
    if (response != null) {
      return response!.statusCode.toString();
    }
    switch (state) {
      case FlowState.pending:
        return 'Pending';
      case FlowState.waiting:
        return 'Waiting';
      case FlowState.receiving:
        return 'Loading';
      case FlowState.failed:
        return 'Error';
      case FlowState.aborted:
        return 'Aborted';
      case FlowState.paused:
        return 'Paused';
      case FlowState.modifying:
        return 'Editing';
      default:
        return '-';
    }
  }

  /// Get the host for grouping
  String get groupHost => request.host;

  /// Get the path for grouping
  String get groupPath {
    final path = request.path;
    // Group by first path segment
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '/';
    return '/${segments.first}';
  }

  /// Create a copy with response
  NetworkFlow withResponse(HttpResponse response) {
    return copyWith(
      response: response,
      state: FlowState.completed,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy with error
  NetworkFlow withError(String error) {
    return copyWith(
      error: error,
      state: FlowState.failed,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy with WebSocket message
  NetworkFlow withWebSocketMessage(WebSocketMessage message) {
    return copyWith(
      webSocketMessages: [...webSocketMessages, message],
      updatedAt: DateTime.now(),
    );
  }
}

/// Represents a WebSocket message
@freezed
class WebSocketMessage with _$WebSocketMessage {
  const WebSocketMessage._();

  const factory WebSocketMessage({
    /// Unique identifier
    required String id,

    /// Direction of the message
    required MessageDirection direction,

    /// Message type
    required WebSocketMessageType type,

    /// Message data as bytes (for binary messages)
    List<int>? dataBytes,

    /// Message data as string (for text messages)
    String? dataText,

    /// Timestamp when message was captured
    required DateTime timestamp,

    /// Message size in bytes
    @Default(0) int size,

    /// Whether message is compressed
    @Default(false) bool isCompressed,
  }) = _WebSocketMessage;

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) =>
      _$WebSocketMessageFromJson(json);

  /// Get formatted data for display
  String get displayData {
    if (dataText != null) return dataText!;
    if (dataBytes != null) return '[Binary: ${dataBytes!.length} bytes]';
    return '[Empty]';
  }
}

/// Direction of a WebSocket message
enum MessageDirection {
  sent,
  received,
}

/// Type of WebSocket message
enum WebSocketMessageType {
  text,
  binary,
  ping,
  pong,
  close,
}

/// Represents a group of flows by domain
@freezed
class FlowGroup with _$FlowGroup {
  const FlowGroup._();

  const factory FlowGroup({
    /// Group key (usually the host)
    required String key,

    /// Display name for the group
    required String displayName,

    /// Flows in this group
    @Default([]) List<NetworkFlow> flows,

    /// Whether the group is expanded in UI
    @Default(true) bool isExpanded,

    /// Subgroups (for path grouping)
    @Default([]) List<FlowGroup> subgroups,
  }) = _FlowGroup;

  factory FlowGroup.fromJson(Map<String, dynamic> json) =>
      _$FlowGroupFromJson(json);

  /// Get the total count of flows including subgroups
  int get totalCount {
    int count = flows.length;
    for (final subgroup in subgroups) {
      count += subgroup.totalCount;
    }
    return count;
  }

  /// Check if any flow in the group has errors
  bool get hasErrors {
    for (final flow in flows) {
      if (flow.state == FlowState.failed) return true;
    }
    for (final subgroup in subgroups) {
      if (subgroup.hasErrors) return true;
    }
    return false;
  }
}
