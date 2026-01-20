import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import 'rules_controller.dart';
import 'map_local_editor.dart';
import 'map_remote_editor.dart';
import 'script_editor.dart';

/// Screen for managing proxy rules (Map Local, Map Remote, Scripts)
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        automaticallyImplyLeading: false, // No back button in tab navigation
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Better for mobile
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Map Local'),
            Tab(text: 'Map Remote'),
            Tab(text: 'Scripting'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addRule(_tabController.index),
            tooltip: 'Add Rule',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'enable_all',
                child: Text('Enable All'),
              ),
              const PopupMenuItem(
                value: 'disable_all',
                child: Text('Disable All'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Text('Import Rules...'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export Rules...'),
              ),
            ],
            onSelected: (value) => _handleMenuAction(value),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MapLocalTab(),
          _MapRemoteTab(),
          _ScriptingTab(),
        ],
      ),
    );
  }

  void _addRule(int tabIndex) {
    switch (tabIndex) {
      case 0:
        _showMapLocalEditor(context, ref);
        break;
      case 1:
        _showMapRemoteEditor(context, ref);
        break;
      case 2:
        _showScriptEditor(context, ref);
        break;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'enable_all':
        ref.read(rulesControllerProvider.notifier).enableAll();
        break;
      case 'disable_all':
        ref.read(rulesControllerProvider.notifier).disableAll();
        break;
      case 'import':
        // TODO: Implement import
        break;
      case 'export':
        // TODO: Implement export
        break;
    }
  }

  void _showMapLocalEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (context) => MapLocalEditorDialog(
        rule: rule,
        onSave: (newRule) {
          if (rule != null) {
            ref.read(rulesControllerProvider.notifier).updateRule(newRule);
          } else {
            ref.read(rulesControllerProvider.notifier).addRule(newRule);
          }
        },
      ),
    );
  }

  void _showMapRemoteEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (context) => MapRemoteEditorDialog(
        rule: rule,
        onSave: (newRule) {
          if (rule != null) {
            ref.read(rulesControllerProvider.notifier).updateRule(newRule);
          } else {
            ref.read(rulesControllerProvider.notifier).addRule(newRule);
          }
        },
      ),
    );
  }

  void _showScriptEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScriptEditorScreen(
          rule: rule,
          onSave: (newRule) {
            if (rule != null) {
              ref.read(rulesControllerProvider.notifier).updateRule(newRule);
            } else {
              ref.read(rulesControllerProvider.notifier).addRule(newRule);
            }
          },
        ),
      ),
    );
  }
}

/// Map Local rules tab
class _MapLocalTab extends ConsumerWidget {
  const _MapLocalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(mapLocalRulesProvider);

    if (rules.isEmpty) {
      return _RuleEmptyState(
        icon: Icons.folder_outlined,
        title: 'No Map Local Rules',
        description:
            'Map local files as responses to matching requests.\nUseful for mocking APIs or testing with local data.',
        onAdd: () => _showEditor(context, ref),
      );
    }

    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _RuleListItem(
          rule: rule,
          icon: Icons.folder_outlined,
          subtitle: rule['localPath'] as String? ?? '',
          onEdit: () => _showEditor(context, ref, rule),
          onDelete: () => ref
              .read(rulesControllerProvider.notifier)
              .deleteRule(rule['id'] as String),
          onToggle: () => ref
              .read(rulesControllerProvider.notifier)
              .toggleRule(rule['id'] as String),
        );
      },
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (context) => MapLocalEditorDialog(
        rule: rule,
        onSave: (newRule) {
          if (rule != null) {
            ref.read(rulesControllerProvider.notifier).updateRule(newRule);
          } else {
            ref.read(rulesControllerProvider.notifier).addRule(newRule);
          }
        },
      ),
    );
  }
}

/// Map Remote rules tab
class _MapRemoteTab extends ConsumerWidget {
  const _MapRemoteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(mapRemoteRulesProvider);

    if (rules.isEmpty) {
      return _RuleEmptyState(
        icon: Icons.swap_horiz,
        title: 'No Map Remote Rules',
        description:
            'Redirect requests to different endpoints.\nUseful for testing against staging or mock servers.',
        onAdd: () => _showEditor(context, ref),
      );
    }

    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _RuleListItem(
          rule: rule,
          icon: Icons.swap_horiz,
          subtitle: '→ ${rule['targetUrl'] as String? ?? ''}',
          onEdit: () => _showEditor(context, ref, rule),
          onDelete: () => ref
              .read(rulesControllerProvider.notifier)
              .deleteRule(rule['id'] as String),
          onToggle: () => ref
              .read(rulesControllerProvider.notifier)
              .toggleRule(rule['id'] as String),
        );
      },
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (context) => MapRemoteEditorDialog(
        rule: rule,
        onSave: (newRule) {
          if (rule != null) {
            ref.read(rulesControllerProvider.notifier).updateRule(newRule);
          } else {
            ref.read(rulesControllerProvider.notifier).addRule(newRule);
          }
        },
      ),
    );
  }
}

/// Scripting rules tab
class _ScriptingTab extends ConsumerWidget {
  const _ScriptingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(scriptRulesProvider);

    if (rules.isEmpty) {
      return _RuleEmptyState(
        icon: Icons.code,
        title: 'No Script Rules',
        description:
            'Use JavaScript to modify requests and responses.\nPowerful for complex transformations and testing.',
        onAdd: () => _showEditor(context, ref),
      );
    }

    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _RuleListItem(
          rule: rule,
          icon: Icons.code,
          subtitle: _getScriptSummary(rule),
          onEdit: () => _showEditor(context, ref, rule),
          onDelete: () => ref
              .read(rulesControllerProvider.notifier)
              .deleteRule(rule['id'] as String),
          onToggle: () => ref
              .read(rulesControllerProvider.notifier)
              .toggleRule(rule['id'] as String),
        );
      },
    );
  }

  String _getScriptSummary(Map<String, dynamic> rule) {
    final hasOnRequest = rule['onRequestScript'] != null;
    final hasOnResponse = rule['onResponseScript'] != null;
    if (hasOnRequest && hasOnResponse) return 'Request & Response';
    if (hasOnRequest) return 'Request only';
    if (hasOnResponse) return 'Response only';
    return 'No scripts';
  }

  void _showEditor(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? rule]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScriptEditorScreen(
          rule: rule,
          onSave: (newRule) {
            if (rule != null) {
              ref.read(rulesControllerProvider.notifier).updateRule(newRule);
            } else {
              ref.read(rulesControllerProvider.notifier).addRule(newRule);
            }
          },
        ),
      ),
    );
  }
}

/// Empty state for rule tabs
class _RuleEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onAdd;

  const _RuleEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Rule'),
          ),
        ],
      ),
    );
  }
}

/// Single rule list item
class _RuleListItem extends StatelessWidget {
  final Map<String, dynamic> rule;
  final IconData icon;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _RuleListItem({
    required this.rule,
    required this.icon,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = rule['name'] as String? ?? 'Unnamed';
    final urlPattern = rule['urlPattern'] as String? ?? '*';
    final isEnabled = rule['isEnabled'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isEnabled,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: isEnabled
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isEnabled ? null : Theme.of(context).colorScheme.outline,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              urlPattern,
              style: Theme.of(context).textTheme.code.copyWith(
                    fontSize: 11,
                    color: isEnabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.outline,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
