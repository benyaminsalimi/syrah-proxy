import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../home_controller.dart';

/// Custom toolbar for non-macOS platforms
class AppToolbar extends ConsumerWidget {
  const AppToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(proxyRunningProvider);
    final flowCount = ref.watch(flowCountProvider);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Proxy control buttons
          _ToolbarButton(
            icon: isRunning ? Icons.stop : Icons.play_arrow,
            label: isRunning ? 'Stop' : 'Start',
            color: isRunning ? AppColors.error : AppColors.success,
            onPressed: () =>
                ref.read(homeControllerProvider.notifier).toggleProxy(),
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: 'Clear',
            onPressed: () =>
                ref.read(homeControllerProvider.notifier).clearFlows(),
          ),
          const _ToolbarDivider(),
          // Status indicator
          _ProxyStatusIndicator(isRunning: isRunning),
          const SizedBox(width: 8),
          Text(
            '$flowCount requests',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // Search field
          SizedBox(
            width: 250,
            child: _SearchField(
              onChanged: (value) =>
                  ref.read(homeControllerProvider.notifier).setSearchText(value),
            ),
          ),
          const _ToolbarDivider(),
          // Filter button
          _FilterButton(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Individual toolbar button
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
              if (Platform.isMacOS) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical divider in toolbar
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 1,
      height: 24,
      color: Theme.of(context).dividerColor,
    );
  }
}

/// Proxy status indicator
class _ProxyStatusIndicator extends StatelessWidget {
  final bool isRunning;

  const _ProxyStatusIndicator({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isRunning ? AppColors.success : AppColors.textSecondaryLight,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isRunning ? 'Recording' : 'Stopped',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isRunning
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Search field widget
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Filter requests...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.outline,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1,
          ),
        ),
      ),
    );
  }
}

/// Filter popup button
class _FilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Filter',
      icon: const Icon(Icons.filter_list, size: 18),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'all',
          child: Text('All Requests'),
        ),
        const PopupMenuItem(
          value: 'xhr',
          child: Text('XHR/Fetch'),
        ),
        const PopupMenuItem(
          value: 'doc',
          child: Text('Documents'),
        ),
        const PopupMenuItem(
          value: 'js',
          child: Text('Scripts'),
        ),
        const PopupMenuItem(
          value: 'css',
          child: Text('Stylesheets'),
        ),
        const PopupMenuItem(
          value: 'img',
          child: Text('Images'),
        ),
        const PopupMenuItem(
          value: 'media',
          child: Text('Media'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'errors',
          child: Text('Errors Only (4xx, 5xx)'),
        ),
        const PopupMenuItem(
          value: 'slow',
          child: Text('Slow Requests (>1s)'),
        ),
      ],
      onSelected: (value) {
        // TODO: Implement filter selection
      },
    );
  }
}
