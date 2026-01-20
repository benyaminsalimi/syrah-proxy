import 'package:freezed_annotation/freezed_annotation.dart';

part 'proxy_rule.freezed.dart';
part 'proxy_rule.g.dart';

/// Type of proxy rule
enum RuleType {
  /// Pause request/response for editing
  breakpoint,

  /// Replace response with local file
  mapLocal,

  /// Redirect request to different URL
  mapRemote,

  /// Block the request entirely
  block,

  /// Run a script on request/response
  script,

  /// Throttle the connection
  throttle,

  /// Add/modify headers
  modifyHeaders,

  /// Modify request/response body
  modifyBody,
}

/// When the rule should be applied
enum RulePhase {
  /// Apply to outgoing requests
  request,

  /// Apply to incoming responses
  response,

  /// Apply to both
  both,
}

/// Represents a proxy rule for modifying traffic
@freezed
class ProxyRule with _$ProxyRule {
  const ProxyRule._();

  const factory ProxyRule({
    /// Unique identifier
    required String id,

    /// Human-readable name for the rule
    required String name,

    /// Type of rule
    required RuleType type,

    /// When to apply the rule
    @Default(RulePhase.both) RulePhase phase,

    /// Matcher for determining which flows this rule applies to
    required RuleMatcher matcher,

    /// Action to perform when rule matches
    required RuleAction action,

    /// Whether the rule is enabled
    @Default(true) bool isEnabled,

    /// Priority (higher = checked first)
    @Default(0) int priority,

    /// Description/notes for the rule
    String? description,

    /// Number of times this rule has been triggered
    @Default(0) int hitCount,

    /// Timestamp when rule was created
    required DateTime createdAt,

    /// Timestamp when rule was last modified
    required DateTime updatedAt,

    /// Timestamp when rule was last triggered
    DateTime? lastTriggeredAt,
  }) = _ProxyRule;

  factory ProxyRule.fromJson(Map<String, dynamic> json) =>
      _$ProxyRuleFromJson(json);

  /// Check if this rule matches a given URL and method
  bool matches(String url, String method, Map<String, String> headers) {
    return matcher.matches(url, method, headers);
  }

  /// Create a breakpoint rule
  factory ProxyRule.breakpoint({
    required String id,
    required String name,
    required RuleMatcher matcher,
    RulePhase phase = RulePhase.both,
    String? description,
  }) {
    final now = DateTime.now();
    return ProxyRule(
      id: id,
      name: name,
      type: RuleType.breakpoint,
      phase: phase,
      matcher: matcher,
      action: const RuleAction.breakpoint(),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a map local rule
  factory ProxyRule.mapLocal({
    required String id,
    required String name,
    required RuleMatcher matcher,
    required String localPath,
    int statusCode = 200,
    Map<String, String> headers = const {},
    String? description,
  }) {
    final now = DateTime.now();
    return ProxyRule(
      id: id,
      name: name,
      type: RuleType.mapLocal,
      phase: RulePhase.response,
      matcher: matcher,
      action: RuleAction.mapLocal(
        localPath: localPath,
        statusCode: statusCode,
        headers: headers,
      ),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a map remote rule
  factory ProxyRule.mapRemote({
    required String id,
    required String name,
    required RuleMatcher matcher,
    required String targetUrl,
    bool preservePath = true,
    bool preserveQuery = true,
    String? description,
  }) {
    final now = DateTime.now();
    return ProxyRule(
      id: id,
      name: name,
      type: RuleType.mapRemote,
      phase: RulePhase.request,
      matcher: matcher,
      action: RuleAction.mapRemote(
        targetUrl: targetUrl,
        preservePath: preservePath,
        preserveQuery: preserveQuery,
      ),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a block rule
  factory ProxyRule.block({
    required String id,
    required String name,
    required RuleMatcher matcher,
    int statusCode = 403,
    String? responseBody,
    String? description,
  }) {
    final now = DateTime.now();
    return ProxyRule(
      id: id,
      name: name,
      type: RuleType.block,
      phase: RulePhase.request,
      matcher: matcher,
      action: RuleAction.block(
        statusCode: statusCode,
        responseBody: responseBody,
      ),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a script rule
  factory ProxyRule.script({
    required String id,
    required String name,
    required RuleMatcher matcher,
    required String scriptContent,
    RulePhase phase = RulePhase.both,
    String? description,
  }) {
    final now = DateTime.now();
    return ProxyRule(
      id: id,
      name: name,
      type: RuleType.script,
      phase: phase,
      matcher: matcher,
      action: RuleAction.script(scriptContent: scriptContent),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Matcher for determining which flows a rule applies to
@freezed
class RuleMatcher with _$RuleMatcher {
  const RuleMatcher._();

  /// Match by URL pattern
  const factory RuleMatcher.url({
    /// URL pattern (supports wildcards * and **)
    required String pattern,

    /// Whether pattern is a regex
    @Default(false) bool isRegex,

    /// Whether match is case-sensitive
    @Default(false) bool caseSensitive,
  }) = UrlMatcher;

  /// Match by host
  const factory RuleMatcher.host({
    required String host,
    @Default(false) bool isRegex,
  }) = HostMatcher;

  /// Match by method
  const factory RuleMatcher.method({
    required List<String> methods,
  }) = MethodMatcher;

  /// Match by header
  const factory RuleMatcher.header({
    required String headerName,
    String? headerValue,
    @Default(false) bool isRegex,
  }) = HeaderMatcher;

  /// Match by content type
  const factory RuleMatcher.contentType({
    required List<String> contentTypes,
  }) = ContentTypeMatcher;

  /// Combined matcher (AND logic)
  const factory RuleMatcher.all({
    required List<RuleMatcher> matchers,
  }) = AllMatcher;

  /// Combined matcher (OR logic)
  const factory RuleMatcher.any({
    required List<RuleMatcher> matchers,
  }) = AnyMatcher;

  /// Negation matcher
  const factory RuleMatcher.not({
    required RuleMatcher matcher,
  }) = NotMatcher;

  factory RuleMatcher.fromJson(Map<String, dynamic> json) =>
      _$RuleMatcherFromJson(json);

  /// Check if this matcher matches the given flow attributes
  bool matches(String url, String method, Map<String, String> headers) {
    return when(
      url: (pattern, isRegex, caseSensitive) {
        if (isRegex) {
          final regex = RegExp(pattern, caseSensitive: caseSensitive);
          return regex.hasMatch(url);
        }
        return _matchWildcard(
            pattern, url, caseSensitive: caseSensitive);
      },
      host: (host, isRegex) {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        if (isRegex) {
          return RegExp(host).hasMatch(uri.host);
        }
        return uri.host == host || uri.host.endsWith('.$host');
      },
      method: (methods) {
        return methods.contains(method.toUpperCase());
      },
      header: (headerName, headerValue, isRegex) {
        final lowerName = headerName.toLowerCase();
        for (final entry in headers.entries) {
          if (entry.key.toLowerCase() == lowerName) {
            if (headerValue == null) return true;
            if (isRegex) {
              return RegExp(headerValue).hasMatch(entry.value);
            }
            return entry.value == headerValue;
          }
        }
        return false;
      },
      contentType: (contentTypes) {
        final ct = headers['content-type'] ?? headers['Content-Type'] ?? '';
        for (final type in contentTypes) {
          if (ct.startsWith(type)) return true;
        }
        return false;
      },
      all: (matchers) {
        for (final m in matchers) {
          if (!m.matches(url, method, headers)) return false;
        }
        return true;
      },
      any: (matchers) {
        for (final m in matchers) {
          if (m.matches(url, method, headers)) return true;
        }
        return false;
      },
      not: (matcher) {
        return !matcher.matches(url, method, headers);
      },
    );
  }

  /// Match a wildcard pattern
  static bool _matchWildcard(String pattern, String text,
      {bool caseSensitive = false}) {
    if (!caseSensitive) {
      pattern = pattern.toLowerCase();
      text = text.toLowerCase();
    }

    // Convert wildcard pattern to regex
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '.*')
        .replaceAll('*', '[^/]*')
        .replaceAll('?', '.');

    return RegExp('^$regexPattern\$').hasMatch(text);
  }
}

/// Action to perform when a rule matches
@freezed
class RuleAction with _$RuleAction {
  const RuleAction._();

  /// Breakpoint action - pause for editing
  const factory RuleAction.breakpoint() = BreakpointAction;

  /// Map to local file
  const factory RuleAction.mapLocal({
    required String localPath,
    @Default(200) int statusCode,
    @Default({}) Map<String, String> headers,
  }) = MapLocalAction;

  /// Redirect to different URL
  const factory RuleAction.mapRemote({
    required String targetUrl,
    @Default(true) bool preservePath,
    @Default(true) bool preserveQuery,
    @Default({}) Map<String, String> additionalHeaders,
  }) = MapRemoteAction;

  /// Block the request
  const factory RuleAction.block({
    @Default(403) int statusCode,
    String? responseBody,
  }) = BlockAction;

  /// Run a script
  const factory RuleAction.script({
    required String scriptContent,
  }) = ScriptAction;

  /// Throttle the connection
  const factory RuleAction.throttle({
    /// Download speed in bytes per second (0 = unlimited)
    @Default(0) int downloadBytesPerSecond,

    /// Upload speed in bytes per second (0 = unlimited)
    @Default(0) int uploadBytesPerSecond,

    /// Additional latency in milliseconds
    @Default(0) int latencyMs,

    /// Packet loss percentage (0-100)
    @Default(0) double packetLossPercent,
  }) = ThrottleAction;

  /// Modify headers
  const factory RuleAction.modifyHeaders({
    /// Headers to add/replace
    @Default({}) Map<String, String> setHeaders,

    /// Headers to remove
    @Default([]) List<String> removeHeaders,
  }) = ModifyHeadersAction;

  /// Modify body
  const factory RuleAction.modifyBody({
    /// New body content
    String? newBody,

    /// Find and replace pairs
    @Default({}) Map<String, String> replacements,
  }) = ModifyBodyAction;

  factory RuleAction.fromJson(Map<String, dynamic> json) =>
      _$RuleActionFromJson(json);
}

/// Preset throttle profiles
class ThrottleProfile {
  final String name;
  final int downloadBytesPerSecond;
  final int uploadBytesPerSecond;
  final int latencyMs;
  final double packetLossPercent;

  const ThrottleProfile({
    required this.name,
    required this.downloadBytesPerSecond,
    required this.uploadBytesPerSecond,
    required this.latencyMs,
    this.packetLossPercent = 0,
  });

  RuleAction toAction() => RuleAction.throttle(
        downloadBytesPerSecond: downloadBytesPerSecond,
        uploadBytesPerSecond: uploadBytesPerSecond,
        latencyMs: latencyMs,
        packetLossPercent: packetLossPercent,
      );

  /// Predefined profiles
  static const slow3G = ThrottleProfile(
    name: 'Slow 3G',
    downloadBytesPerSecond: 50000, // 400 Kbps
    uploadBytesPerSecond: 50000,
    latencyMs: 400,
  );

  static const fast3G = ThrottleProfile(
    name: 'Fast 3G',
    downloadBytesPerSecond: 187500, // 1.5 Mbps
    uploadBytesPerSecond: 93750, // 750 Kbps
    latencyMs: 150,
  );

  static const slow4G = ThrottleProfile(
    name: 'Slow 4G',
    downloadBytesPerSecond: 500000, // 4 Mbps
    uploadBytesPerSecond: 375000, // 3 Mbps
    latencyMs: 100,
  );

  static const fast4G = ThrottleProfile(
    name: 'Fast 4G',
    downloadBytesPerSecond: 2500000, // 20 Mbps
    uploadBytesPerSecond: 1250000, // 10 Mbps
    latencyMs: 50,
  );

  static const wifi = ThrottleProfile(
    name: 'WiFi',
    downloadBytesPerSecond: 3750000, // 30 Mbps
    uploadBytesPerSecond: 1875000, // 15 Mbps
    latencyMs: 10,
  );

  static const offline = ThrottleProfile(
    name: 'Offline',
    downloadBytesPerSecond: 0,
    uploadBytesPerSecond: 0,
    latencyMs: 0,
    packetLossPercent: 100,
  );

  static const List<ThrottleProfile> presets = [
    slow3G,
    fast3G,
    slow4G,
    fast4G,
    wifi,
    offline,
  ];
}
