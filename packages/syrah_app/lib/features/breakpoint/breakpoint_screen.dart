import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import 'breakpoint_controller.dart';
import 'breakpoint_editor.dart';

/// Screen for managing breakpoint rules
class BreakpointScreen extends ConsumerWidget {
  const BreakpointScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoints = ref.watch(breakpointListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breakpoints'),
        automaticallyImplyLeading: false, // No back button in tab navigation
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showBreakpointEditor(context, ref),
            tooltip: 'Add Breakpoint',
          ),
        ],
      ),
      body: breakpoints.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              itemCount: breakpoints.length,
              itemBuilder: (context, index) {
                final breakpoint = breakpoints[index];
                return _BreakpointListItem(
                  breakpoint: breakpoint,
                  onEdit: () => _showBreakpointEditor(context, ref, breakpoint),
                  onDelete: () => ref
                      .read(breakpointControllerProvider.notifier)
                      .deleteBreakpoint(breakpoint['id'] as String),
                  onToggle: () => ref
                      .read(breakpointControllerProvider.notifier)
                      .toggleBreakpoint(breakpoint['id'] as String),
                );
              },
            ),
    );
  }

  void _showBreakpointEditor(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? breakpoint,
  ]) {
    showDialog(
      context: context,
      builder: (context) => BreakpointEditorDialog(
        breakpoint: breakpoint,
        onSave: (newBreakpoint) {
          if (breakpoint != null) {
            ref
                .read(breakpointControllerProvider.notifier)
                .updateBreakpoint(newBreakpoint);
          } else {
            ref
                .read(breakpointControllerProvider.notifier)
                .addBreakpoint(newBreakpoint);
          }
        },
      ),
    );
  }
}

/// Empty state when no breakpoints exist
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pause_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No breakpoints',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a breakpoint to pause and modify\nrequests or responses',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // Show editor
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Breakpoint'),
          ),
        ],
      ),
    );
  }
}

/// Single breakpoint list item
class _BreakpointListItem extends StatelessWidget {
  final Map<String, dynamic> breakpoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _BreakpointListItem({
    required this.breakpoint,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = breakpoint['name'] as String? ?? 'Unnamed';
    final urlPattern = breakpoint['urlPattern'] as String? ?? '*';
    final isEnabled = breakpoint['isEnabled'] as bool? ?? true;
    final breakOnRequest = breakpoint['breakOnRequest'] as bool? ?? true;
    final breakOnResponse = breakpoint['breakOnResponse'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Switch(
          value: isEnabled,
          onChanged: (_) => onToggle(),
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
            const SizedBox(height: 4),
            Row(
              children: [
                if (breakOnRequest)
                  _TypeChip(
                    label: 'Request',
                    color: AppColors.methodPost,
                    isEnabled: isEnabled,
                  ),
                if (breakOnRequest && breakOnResponse)
                  const SizedBox(width: 4),
                if (breakOnResponse)
                  _TypeChip(
                    label: 'Response',
                    color: AppColors.methodGet,
                    isEnabled: isEnabled,
                  ),
              ],
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

/// Type chip indicator
class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isEnabled;

  const _TypeChip({
    required this.label,
    required this.color,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isEnabled ? color : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isEnabled ? color : Colors.grey,
        ),
      ),
    );
  }
}
