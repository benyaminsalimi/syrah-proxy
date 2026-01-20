import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// State for breakpoint management
class BreakpointState {
  final List<Map<String, dynamic>> breakpoints;
  final Map<String, dynamic>? activeHit;

  const BreakpointState({
    this.breakpoints = const [],
    this.activeHit,
  });

  BreakpointState copyWith({
    List<Map<String, dynamic>>? breakpoints,
    Map<String, dynamic>? activeHit,
    bool clearActiveHit = false,
  }) {
    return BreakpointState(
      breakpoints: breakpoints ?? this.breakpoints,
      activeHit: clearActiveHit ? null : (activeHit ?? this.activeHit),
    );
  }
}

/// Controller for managing breakpoints
class BreakpointController extends StateNotifier<BreakpointState> {
  BreakpointController() : super(const BreakpointState());

  final _uuid = const Uuid();

  /// Add a new breakpoint
  void addBreakpoint(Map<String, dynamic> breakpoint) {
    final newBreakpoint = {
      ...breakpoint,
      'id': _uuid.v4(),
      'isEnabled': breakpoint['isEnabled'] ?? true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    state = state.copyWith(
      breakpoints: [...state.breakpoints, newBreakpoint],
    );
  }

  /// Update an existing breakpoint
  void updateBreakpoint(Map<String, dynamic> breakpoint) {
    final index = state.breakpoints.indexWhere(
      (b) => b['id'] == breakpoint['id'],
    );
    if (index != -1) {
      final newBreakpoints = [...state.breakpoints];
      newBreakpoints[index] = {
        ...newBreakpoints[index],
        ...breakpoint,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      state = state.copyWith(breakpoints: newBreakpoints);
    }
  }

  /// Delete a breakpoint
  void deleteBreakpoint(String id) {
    state = state.copyWith(
      breakpoints: state.breakpoints.where((b) => b['id'] != id).toList(),
    );
  }

  /// Toggle breakpoint enabled state
  void toggleBreakpoint(String id) {
    final index = state.breakpoints.indexWhere((b) => b['id'] == id);
    if (index != -1) {
      final newBreakpoints = [...state.breakpoints];
      final current = newBreakpoints[index]['isEnabled'] as bool? ?? true;
      newBreakpoints[index] = {
        ...newBreakpoints[index],
        'isEnabled': !current,
      };
      state = state.copyWith(breakpoints: newBreakpoints);
    }
  }

  /// Check if a flow matches any enabled breakpoint
  Map<String, dynamic>? checkBreakpoint(
    Map<String, dynamic> flow,
    bool isRequest,
  ) {
    final enabledBreakpoints = state.breakpoints.where(
      (b) => b['isEnabled'] as bool? ?? true,
    );

    for (final breakpoint in enabledBreakpoints) {
      if (_matchesBreakpoint(flow, breakpoint, isRequest)) {
        return breakpoint;
      }
    }
    return null;
  }

  bool _matchesBreakpoint(
    Map<String, dynamic> flow,
    Map<String, dynamic> breakpoint,
    bool isRequest,
  ) {
    // Check if we should break on this phase
    if (isRequest && !(breakpoint['breakOnRequest'] as bool? ?? true)) {
      return false;
    }
    if (!isRequest && !(breakpoint['breakOnResponse'] as bool? ?? false)) {
      return false;
    }

    final request = flow['request'] as Map<String, dynamic>?;
    if (request == null) return false;

    // URL pattern matching
    final urlPattern = breakpoint['urlPattern'] as String?;
    if (urlPattern != null && urlPattern.isNotEmpty && urlPattern != '*') {
      final url = request['url'] as String? ?? '';
      if (!_matchesPattern(url, urlPattern)) {
        return false;
      }
    }

    // Method matching
    final methods = breakpoint['methods'] as List<dynamic>?;
    if (methods != null && methods.isNotEmpty) {
      final method = request['method'] as String? ?? 'GET';
      if (!methods.contains(method)) {
        return false;
      }
    }

    // Header matching
    final headerMatchers = breakpoint['headerMatchers'] as List<dynamic>?;
    if (headerMatchers != null && headerMatchers.isNotEmpty) {
      final headers = request['headers'] as Map<String, dynamic>? ?? {};
      for (final matcher in headerMatchers) {
        final headerName = matcher['name'] as String?;
        final headerPattern = matcher['pattern'] as String?;
        if (headerName != null && headerPattern != null) {
          final headerValue = headers[headerName]?.toString() ?? '';
          if (!_matchesPattern(headerValue, headerPattern)) {
            return false;
          }
        }
      }
    }

    return true;
  }

  bool _matchesPattern(String value, String pattern) {
    // Support simple wildcard patterns
    if (pattern == '*') return true;

    // Convert wildcard pattern to regex
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');

    try {
      final regex = RegExp('^$regexPattern\$', caseSensitive: false);
      return regex.hasMatch(value);
    } catch (_) {
      // If regex is invalid, do simple contains match
      return value.toLowerCase().contains(pattern.toLowerCase());
    }
  }

  /// Set active breakpoint hit
  void setActiveHit(Map<String, dynamic> flow, Map<String, dynamic> breakpoint) {
    state = state.copyWith(
      activeHit: {
        'flow': flow,
        'breakpoint': breakpoint,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Clear active breakpoint hit
  void clearActiveHit() {
    state = state.copyWith(clearActiveHit: true);
  }

  /// Resume flow with optional modifications
  void resumeFlow(Map<String, dynamic>? modifiedFlow) {
    // In real implementation, this would communicate with the proxy
    // to continue the paused flow with any modifications
    clearActiveHit();
  }

  /// Abort the paused flow
  void abortFlow() {
    // In real implementation, this would tell the proxy to abort the flow
    clearActiveHit();
  }
}

/// Provider for breakpoint controller
final breakpointControllerProvider =
    StateNotifierProvider<BreakpointController, BreakpointState>((ref) {
  return BreakpointController();
});

/// Provider for breakpoint list
final breakpointListProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(breakpointControllerProvider).breakpoints;
});

/// Provider for active breakpoint hit
final activeBreakpointHitProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(breakpointControllerProvider).activeHit;
});

/// Provider for enabled breakpoints count
final enabledBreakpointsCountProvider = Provider<int>((ref) {
  final breakpoints = ref.watch(breakpointListProvider);
  return breakpoints.where((b) => b['isEnabled'] as bool? ?? true).length;
});
