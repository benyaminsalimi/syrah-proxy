import 'package:freezed_annotation/freezed_annotation.dart';

import 'network_flow.dart';
import 'proxy_rule.dart';
import 'filter.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// State of the proxy/capture session
enum SessionState {
  /// Session is idle, not capturing
  stopped,

  /// Session is starting up
  starting,

  /// Session is actively capturing
  running,

  /// Session is pausing
  pausing,

  /// Session is paused
  paused,

  /// Session is stopping
  stopping,

  /// Session encountered an error
  error,
}

/// Represents a capture session
@freezed
class Session with _$Session {
  const Session._();

  const factory Session({
    /// Unique identifier
    required String id,

    /// Human-readable name
    required String name,

    /// Session state
    @Default(SessionState.stopped) SessionState state,

    /// Flows captured in this session
    @Default([]) List<NetworkFlow> flows,

    /// Rules active in this session
    @Default([]) List<ProxyRule> rules,

    /// Filter state
    @Default(FilterState()) FilterState filterState,

    /// Session metadata
    SessionMetadata? metadata,

    /// Error message if state is error
    String? error,

    /// Timestamp when session was created
    required DateTime createdAt,

    /// Timestamp when session was last modified
    required DateTime updatedAt,

    /// Timestamp when capture started
    DateTime? startedAt,

    /// Timestamp when capture stopped
    DateTime? stoppedAt,

    /// Whether auto-scroll is enabled
    @Default(true) bool autoScroll,

    /// Maximum number of flows to retain (0 = unlimited)
    @Default(0) int maxFlows,

    /// Whether to preserve logs on clear
    @Default(false) bool preserveLogsOnClear,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  /// Get the count of captured flows
  int get flowCount => flows.length;

  /// Get the count of flows matching current filter
  int get filteredFlowCount {
    if (!filterState.hasActiveFilter) return flows.length;
    return flows.where((f) => filterState.matches(f)).length;
  }

  /// Get filtered flows
  List<NetworkFlow> get filteredFlows {
    if (!filterState.hasActiveFilter) return flows;
    return flows.where((f) => filterState.matches(f)).toList();
  }

  /// Get the total captured data size
  int get totalSize {
    int size = 0;
    for (final flow in flows) {
      size += flow.totalSize;
    }
    return size;
  }

  /// Get formatted total size
  String get formattedTotalSize {
    final bytes = totalSize;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get duration of the session
  Duration? get duration {
    if (startedAt == null) return null;
    final end = stoppedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Get error count
  int get errorCount {
    int count = 0;
    for (final flow in flows) {
      if (flow.state == FlowState.failed ||
          (flow.response?.isError ?? false)) {
        count++;
      }
    }
    return count;
  }

  /// Get unique hosts
  Set<String> get hosts {
    return flows.map((f) => f.request.host).toSet();
  }

  /// Check if session is capturing
  bool get isCapturing => state == SessionState.running;

  /// Check if session can be started
  bool get canStart =>
      state == SessionState.stopped ||
      state == SessionState.paused ||
      state == SessionState.error;

  /// Check if session can be stopped
  bool get canStop => state == SessionState.running || state == SessionState.paused;

  /// Add a flow to the session
  Session addFlow(NetworkFlow flow) {
    final newFlows = [...flows, flow];
    // Apply max flows limit
    final trimmedFlows = maxFlows > 0 && newFlows.length > maxFlows
        ? newFlows.sublist(newFlows.length - maxFlows)
        : newFlows;
    return copyWith(
      flows: trimmedFlows,
      updatedAt: DateTime.now(),
    );
  }

  /// Update a flow in the session
  Session updateFlow(NetworkFlow flow) {
    final index = flows.indexWhere((f) => f.id == flow.id);
    if (index == -1) return this;
    final newFlows = [...flows];
    newFlows[index] = flow;
    return copyWith(
      flows: newFlows,
      updatedAt: DateTime.now(),
    );
  }

  /// Clear all flows
  Session clearFlows() {
    return copyWith(
      flows: [],
      updatedAt: DateTime.now(),
    );
  }

  /// Create a new session with default values
  factory Session.create({String? name}) {
    final now = DateTime.now();
    return Session(
      id: 'session_${now.millisecondsSinceEpoch}',
      name: name ?? 'Session ${now.toIso8601String().substring(0, 10)}',
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Session metadata
@freezed
class SessionMetadata with _$SessionMetadata {
  const SessionMetadata._();

  const factory SessionMetadata({
    /// Device name
    String? deviceName,

    /// Platform (macOS, Android, etc.)
    String? platform,

    /// Platform version
    String? platformVersion,

    /// App version
    String? appVersion,

    /// Proxy port used
    int? proxyPort,

    /// Whether SSL interception was enabled
    @Default(false) bool sslInterceptionEnabled,

    /// Target application (if filtering by app)
    String? targetApp,

    /// Custom notes
    String? notes,

    /// Tags for organization
    @Default([]) List<String> tags,
  }) = _SessionMetadata;

  factory SessionMetadata.fromJson(Map<String, dynamic> json) =>
      _$SessionMetadataFromJson(json);
}

/// Proxy status information
@freezed
class ProxyStatus with _$ProxyStatus {
  const ProxyStatus._();

  const factory ProxyStatus({
    /// Whether proxy is running
    @Default(false) bool isRunning,

    /// Proxy port
    @Default(8888) int port,

    /// Proxy address
    @Default('127.0.0.1') String address,

    /// Number of active connections
    @Default(0) int activeConnections,

    /// Total bytes received
    @Default(0) int bytesReceived,

    /// Total bytes sent
    @Default(0) int bytesSent,

    /// Whether SSL interception is enabled
    @Default(false) bool sslInterceptionEnabled,

    /// Whether transparent proxy mode is enabled
    @Default(false) bool transparentMode,

    /// List of trusted certificate fingerprints
    @Default([]) List<String> trustedCertificates,

    /// Error message if any
    String? error,
  }) = _ProxyStatus;

  factory ProxyStatus.fromJson(Map<String, dynamic> json) =>
      _$ProxyStatusFromJson(json);

  /// Get the proxy URL
  String get proxyUrl => 'http://$address:$port';

  /// Get formatted traffic stats
  String get formattedTraffic {
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    return '↓ ${formatBytes(bytesReceived)} / ↑ ${formatBytes(bytesSent)}';
  }
}

/// Proxy configuration
@freezed
class ProxyConfig with _$ProxyConfig {
  const ProxyConfig._();

  const factory ProxyConfig({
    /// Proxy port to listen on
    @Default(8888) int port,

    /// Address to bind to (empty = all interfaces)
    @Default('127.0.0.1') String bindAddress,

    /// Whether to enable SSL interception
    @Default(true) bool enableSslInterception,

    /// Whether to enable transparent proxy mode
    @Default(false) bool enableTransparentMode,

    /// Upstream proxy URL (if using proxy chain)
    String? upstreamProxy,

    /// Upstream proxy authentication
    String? upstreamProxyAuth,

    /// Hosts to bypass (don't intercept)
    @Default([]) List<String> bypassHosts,

    /// Whether to verify upstream SSL certificates
    @Default(true) bool verifyUpstreamSsl,

    /// Connection timeout in milliseconds
    @Default(30000) int connectionTimeoutMs,

    /// Read timeout in milliseconds
    @Default(60000) int readTimeoutMs,

    /// Maximum concurrent connections
    @Default(100) int maxConnections,

    /// Whether to capture request bodies
    @Default(true) bool captureRequestBodies,

    /// Whether to capture response bodies
    @Default(true) bool captureResponseBodies,

    /// Maximum body size to capture (bytes, 0 = unlimited)
    @Default(10 * 1024 * 1024) int maxBodySize,

    /// Whether to decompress response bodies
    @Default(true) bool decompressResponses,
  }) = _ProxyConfig;

  factory ProxyConfig.fromJson(Map<String, dynamic> json) =>
      _$ProxyConfigFromJson(json);

  /// Default configuration
  static const ProxyConfig defaultConfig = ProxyConfig();
}

/// Certificate information
@freezed
class CertificateInfo with _$CertificateInfo {
  const CertificateInfo._();

  const factory CertificateInfo({
    /// Certificate subject
    required String subject,

    /// Certificate issuer
    required String issuer,

    /// Serial number
    required String serialNumber,

    /// Not valid before
    required DateTime notBefore,

    /// Not valid after
    required DateTime notAfter,

    /// SHA-256 fingerprint
    required String fingerprint,

    /// Whether this is a CA certificate
    @Default(false) bool isCA,

    /// Whether this is the root CA
    @Default(false) bool isRootCA,

    /// PEM encoded certificate
    String? pemData,
  }) = _CertificateInfo;

  factory CertificateInfo.fromJson(Map<String, dynamic> json) =>
      _$CertificateInfoFromJson(json);

  /// Check if certificate is valid
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(notBefore) && now.isBefore(notAfter);
  }

  /// Check if certificate is expiring soon (within 30 days)
  bool get isExpiringSoon {
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return notAfter.isBefore(thirtyDaysFromNow);
  }

  /// Get days until expiration
  int get daysUntilExpiration {
    return notAfter.difference(DateTime.now()).inDays;
  }
}
