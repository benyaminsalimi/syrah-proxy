import 'dart:async';

import '../models/models.dart';

/// Service for managing proxy rules
class RuleService {
  final _ruleController = StreamController<List<ProxyRule>>.broadcast();

  final List<ProxyRule> _rules = [];
  final Map<String, ProxyRule> _rulesById = {};

  /// Stream of rule list updates
  Stream<List<ProxyRule>> get ruleStream => _ruleController.stream;

  /// Get all rules
  List<ProxyRule> get rules => List.unmodifiable(_rules);

  /// Get enabled rules only (sorted by priority)
  List<ProxyRule> get enabledRules {
    return _rules.where((r) => r.isEnabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Get a rule by ID
  ProxyRule? getRule(String id) => _rulesById[id];

  /// Get rules by type
  List<ProxyRule> getRulesByType(RuleType type) {
    return _rules.where((r) => r.type == type).toList();
  }

  /// Add a new rule
  void addRule(ProxyRule rule) {
    _rules.add(rule);
    _rulesById[rule.id] = rule;
    _ruleController.add(rules);
  }

  /// Update an existing rule
  void updateRule(ProxyRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      _rulesById[rule.id] = rule;
      _ruleController.add(rules);
    }
  }

  /// Remove a rule
  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    _rulesById.remove(id);
    _ruleController.add(rules);
  }

  /// Enable/disable a rule
  void toggleRule(String id) {
    final rule = _rulesById[id];
    if (rule != null) {
      updateRule(rule.copyWith(
        isEnabled: !rule.isEnabled,
        updatedAt: DateTime.now(),
      ));
    }
  }

  /// Clear all rules
  void clearRules() {
    _rules.clear();
    _rulesById.clear();
    _ruleController.add(rules);
  }

  /// Find matching rules for a given request
  List<ProxyRule> findMatchingRules(
    String url,
    String method,
    Map<String, String> headers,
  ) {
    return enabledRules.where((r) => r.matches(url, method, headers)).toList();
  }

  /// Find first matching rule of a specific type
  ProxyRule? findFirstMatchingRule(
    String url,
    String method,
    Map<String, String> headers,
    RuleType type,
  ) {
    for (final rule in enabledRules) {
      if (rule.type == type && rule.matches(url, method, headers)) {
        return rule;
      }
    }
    return null;
  }

  /// Record a rule hit
  void recordHit(String id) {
    final rule = _rulesById[id];
    if (rule != null) {
      updateRule(rule.copyWith(
        hitCount: rule.hitCount + 1,
        lastTriggeredAt: DateTime.now(),
      ));
    }
  }

  /// Reorder rules (change priority)
  void reorderRules(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final rule = _rules.removeAt(oldIndex);
    _rules.insert(newIndex, rule);

    // Update priorities based on new order
    for (int i = 0; i < _rules.length; i++) {
      final updatedRule = _rules[i].copyWith(
        priority: _rules.length - i,
        updatedAt: DateTime.now(),
      );
      _rules[i] = updatedRule;
      _rulesById[updatedRule.id] = updatedRule;
    }

    _ruleController.add(rules);
  }

  /// Import rules from a list
  void importRules(List<ProxyRule> rules, {bool replace = false}) {
    if (replace) {
      _rules.clear();
      _rulesById.clear();
    }

    for (final rule in rules) {
      if (_rulesById.containsKey(rule.id)) {
        // Update existing rule
        updateRule(rule);
      } else {
        // Add new rule
        addRule(rule);
      }
    }
  }

  /// Export rules to a list
  List<Map<String, dynamic>> exportRules() {
    return _rules.map((r) => r.toJson()).toList();
  }

  /// Dispose of resources
  void dispose() {
    _ruleController.close();
  }
}

/// Helper class for building rules
class RuleBuilder {
  String? _id;
  String? _name;
  RuleType? _type;
  RulePhase _phase = RulePhase.both;
  RuleMatcher? _matcher;
  RuleAction? _action;
  bool _isEnabled = true;
  int _priority = 0;
  String? _description;

  RuleBuilder();

  RuleBuilder id(String id) {
    _id = id;
    return this;
  }

  RuleBuilder name(String name) {
    _name = name;
    return this;
  }

  RuleBuilder type(RuleType type) {
    _type = type;
    return this;
  }

  RuleBuilder phase(RulePhase phase) {
    _phase = phase;
    return this;
  }

  RuleBuilder matcher(RuleMatcher matcher) {
    _matcher = matcher;
    return this;
  }

  RuleBuilder action(RuleAction action) {
    _action = action;
    return this;
  }

  RuleBuilder enabled(bool enabled) {
    _isEnabled = enabled;
    return this;
  }

  RuleBuilder priority(int priority) {
    _priority = priority;
    return this;
  }

  RuleBuilder description(String? description) {
    _description = description;
    return this;
  }

  /// Build a breakpoint rule
  RuleBuilder breakpoint() {
    _type = RuleType.breakpoint;
    _action = const RuleAction.breakpoint();
    return this;
  }

  /// Build a block rule
  RuleBuilder block({int statusCode = 403, String? responseBody}) {
    _type = RuleType.block;
    _phase = RulePhase.request;
    _action = RuleAction.block(statusCode: statusCode, responseBody: responseBody);
    return this;
  }

  /// Build a map local rule
  RuleBuilder mapLocal(String localPath, {int statusCode = 200}) {
    _type = RuleType.mapLocal;
    _phase = RulePhase.response;
    _action = RuleAction.mapLocal(localPath: localPath, statusCode: statusCode);
    return this;
  }

  /// Build a map remote rule
  RuleBuilder mapRemote(String targetUrl, {bool preservePath = true}) {
    _type = RuleType.mapRemote;
    _phase = RulePhase.request;
    _action = RuleAction.mapRemote(targetUrl: targetUrl, preservePath: preservePath);
    return this;
  }

  /// Match by URL pattern
  RuleBuilder matchUrl(String pattern, {bool isRegex = false}) {
    _matcher = RuleMatcher.url(pattern: pattern, isRegex: isRegex);
    return this;
  }

  /// Match by host
  RuleBuilder matchHost(String host) {
    _matcher = RuleMatcher.host(host: host);
    return this;
  }

  /// Match by method
  RuleBuilder matchMethod(List<String> methods) {
    _matcher = RuleMatcher.method(methods: methods);
    return this;
  }

  ProxyRule build() {
    if (_id == null) throw ArgumentError('Rule ID is required');
    if (_name == null) throw ArgumentError('Rule name is required');
    if (_type == null) throw ArgumentError('Rule type is required');
    if (_matcher == null) throw ArgumentError('Rule matcher is required');
    if (_action == null) throw ArgumentError('Rule action is required');

    final now = DateTime.now();
    return ProxyRule(
      id: _id!,
      name: _name!,
      type: _type!,
      phase: _phase,
      matcher: _matcher!,
      action: _action!,
      isEnabled: _isEnabled,
      priority: _priority,
      description: _description,
      createdAt: now,
      updatedAt: now,
    );
  }
}
