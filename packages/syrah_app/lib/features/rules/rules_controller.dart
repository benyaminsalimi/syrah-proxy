import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Rule types
enum RuleType {
  mapLocal,
  mapRemote,
  script,
}

/// State for rules management
class RulesState {
  final List<Map<String, dynamic>> rules;

  const RulesState({this.rules = const []});

  RulesState copyWith({List<Map<String, dynamic>>? rules}) {
    return RulesState(rules: rules ?? this.rules);
  }

  List<Map<String, dynamic>> getRulesByType(RuleType type) {
    final typeString = type.name;
    return rules.where((r) => r['type'] == typeString).toList();
  }
}

/// Controller for managing proxy rules
class RulesController extends StateNotifier<RulesState> {
  RulesController() : super(const RulesState());

  final _uuid = const Uuid();

  /// Add a new rule
  void addRule(Map<String, dynamic> rule) {
    final newRule = {
      ...rule,
      'id': _uuid.v4(),
      'isEnabled': rule['isEnabled'] ?? true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    state = state.copyWith(rules: [...state.rules, newRule]);
  }

  /// Update an existing rule
  void updateRule(Map<String, dynamic> rule) {
    final index = state.rules.indexWhere((r) => r['id'] == rule['id']);
    if (index != -1) {
      final newRules = [...state.rules];
      newRules[index] = {
        ...newRules[index],
        ...rule,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      state = state.copyWith(rules: newRules);
    }
  }

  /// Delete a rule
  void deleteRule(String id) {
    state = state.copyWith(
      rules: state.rules.where((r) => r['id'] != id).toList(),
    );
  }

  /// Toggle rule enabled state
  void toggleRule(String id) {
    final index = state.rules.indexWhere((r) => r['id'] == id);
    if (index != -1) {
      final newRules = [...state.rules];
      final current = newRules[index]['isEnabled'] as bool? ?? true;
      newRules[index] = {
        ...newRules[index],
        'isEnabled': !current,
      };
      state = state.copyWith(rules: newRules);
    }
  }

  /// Enable all rules
  void enableAll() {
    final newRules = state.rules.map((r) {
      return {...r, 'isEnabled': true};
    }).toList();
    state = state.copyWith(rules: newRules);
  }

  /// Disable all rules
  void disableAll() {
    final newRules = state.rules.map((r) {
      return {...r, 'isEnabled': false};
    }).toList();
    state = state.copyWith(rules: newRules);
  }

  /// Check if a request matches any enabled rule
  Map<String, dynamic>? findMatchingRule(
    Map<String, dynamic> request,
    RuleType type,
  ) {
    final enabledRules = state.rules.where((r) =>
        r['type'] == type.name && (r['isEnabled'] as bool? ?? true));

    for (final rule in enabledRules) {
      if (_matchesRule(request, rule)) {
        return rule;
      }
    }
    return null;
  }

  bool _matchesRule(Map<String, dynamic> request, Map<String, dynamic> rule) {
    final url = request['url'] as String? ?? '';
    final urlPattern = rule['urlPattern'] as String?;

    if (urlPattern != null && urlPattern.isNotEmpty && urlPattern != '*') {
      if (!_matchesPattern(url, urlPattern)) {
        return false;
      }
    }

    // Check method if specified
    final methods = rule['methods'] as List<dynamic>?;
    if (methods != null && methods.isNotEmpty) {
      final method = request['method'] as String? ?? 'GET';
      if (!methods.contains(method)) {
        return false;
      }
    }

    return true;
  }

  bool _matchesPattern(String value, String pattern) {
    if (pattern == '*') return true;

    // Support regex patterns
    if (pattern.startsWith('/') && pattern.endsWith('/')) {
      try {
        final regex = RegExp(pattern.substring(1, pattern.length - 1));
        return regex.hasMatch(value);
      } catch (_) {
        return false;
      }
    }

    // Convert wildcard pattern to regex
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');

    try {
      final regex = RegExp('^$regexPattern\$', caseSensitive: false);
      return regex.hasMatch(value);
    } catch (_) {
      return value.toLowerCase().contains(pattern.toLowerCase());
    }
  }

  /// Import rules from JSON
  void importRules(List<Map<String, dynamic>> rules) {
    final newRules = rules.map((r) {
      return {
        ...r,
        'id': _uuid.v4(),
        'importedAt': DateTime.now().toIso8601String(),
      };
    }).toList();
    state = state.copyWith(rules: [...state.rules, ...newRules]);
  }

  /// Export rules to JSON
  List<Map<String, dynamic>> exportRules() {
    return state.rules.map((r) {
      final exported = Map<String, dynamic>.from(r);
      exported.remove('id');
      return exported;
    }).toList();
  }
}

/// Provider for rules controller
final rulesControllerProvider =
    StateNotifierProvider<RulesController, RulesState>((ref) {
  return RulesController();
});

/// Provider for all rules
final allRulesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rulesControllerProvider).rules;
});

/// Provider for Map Local rules
final mapLocalRulesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rulesControllerProvider).getRulesByType(RuleType.mapLocal);
});

/// Provider for Map Remote rules
final mapRemoteRulesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rulesControllerProvider).getRulesByType(RuleType.mapRemote);
});

/// Provider for Script rules
final scriptRulesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rulesControllerProvider).getRulesByType(RuleType.script);
});

/// Provider for enabled rules count
final enabledRulesCountProvider = Provider<int>((ref) {
  final rules = ref.watch(allRulesProvider);
  return rules.where((r) => r['isEnabled'] as bool? ?? true).length;
});
