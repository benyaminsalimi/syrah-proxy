import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';

/// Screen for WebSocket debugging
class WebSocketScreen extends ConsumerStatefulWidget {
  const WebSocketScreen({super.key});

  @override
  ConsumerState<WebSocketScreen> createState() => _WebSocketScreenState();
}

class _WebSocketScreenState extends ConsumerState<WebSocketScreen> {
  Map<String, dynamic>? _selectedConnection;

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(webSocketConnectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(webSocketControllerProvider.notifier).clearAll(),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: connections.isEmpty
          ? const _EmptyState()
          : Row(
              children: [
                // Connection list
                SizedBox(
                  width: 300,
                  child: _ConnectionList(
                    connections: connections,
                    selectedConnection: _selectedConnection,
                    onSelect: (conn) =>
                        setState(() => _selectedConnection = conn),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Message view
                Expanded(
                  child: _selectedConnection == null
                      ? const Center(
                          child: Text('Select a connection to view messages'),
                        )
                      : _MessageView(connection: _selectedConnection!),
                ),
              ],
            ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cable,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No WebSocket Connections',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'WebSocket connections will appear here\nwhen captured by the proxy',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// WebSocket connection list
class _ConnectionList extends StatelessWidget {
  final List<Map<String, dynamic>> connections;
  final Map<String, dynamic>? selectedConnection;
  final Function(Map<String, dynamic>) onSelect;

  const _ConnectionList({
    required this.connections,
    required this.selectedConnection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Connections',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${connections.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final conn = connections[index];
              final isSelected = selectedConnection?['id'] == conn['id'];

              return _ConnectionListItem(
                connection: conn,
                isSelected: isSelected,
                onTap: () => onSelect(conn),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Single connection list item
class _ConnectionListItem extends StatelessWidget {
  final Map<String, dynamic> connection;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConnectionListItem({
    required this.connection,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = connection['url'] as String? ?? '';
    final state = connection['state'] as String? ?? 'unknown';
    final messageCount = (connection['messages'] as List?)?.length ?? 0;

    final uri = Uri.tryParse(url);
    final host = uri?.host ?? url;

    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StateIndicator(state: state),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      host,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$messageCount messages',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connection state indicator
class _StateIndicator extends StatelessWidget {
  final String state;

  const _StateIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (state) {
      case 'connected':
        color = AppColors.success;
        icon = Icons.link;
        break;
      case 'disconnected':
        color = AppColors.textSecondaryLight;
        icon = Icons.link_off;
        break;
      case 'error':
        color = AppColors.error;
        icon = Icons.error_outline;
        break;
      default:
        color = AppColors.warning;
        icon = Icons.pending;
    }

    return Icon(icon, size: 16, color: color);
  }
}

/// Message view for a WebSocket connection
class _MessageView extends StatefulWidget {
  final Map<String, dynamic> connection;

  const _MessageView({required this.connection});

  @override
  State<_MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<_MessageView> {
  final _messageController = TextEditingController();
  String _filter = 'all';

  List<Map<String, dynamic>> get _filteredMessages {
    final messages =
        (widget.connection['messages'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    switch (_filter) {
      case 'sent':
        return messages.where((m) => m['direction'] == 'outgoing').toList();
      case 'received':
        return messages.where((m) => m['direction'] == 'incoming').toList();
      default:
        return messages;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _filteredMessages;
    final url = widget.connection['url'] as String? ?? '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: Theme.of(context).textTheme.code.copyWith(
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied')),
                      );
                    },
                    tooltip: 'Copy URL',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'sent', label: Text('Sent')),
                  ButtonSegment(value: 'received', label: Text('Received')),
                ],
                selected: {_filter},
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageItem(message: message);
                  },
                ),
        ),
        // Send message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Send a message...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // In real implementation, this would send via the proxy
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message would be sent here')),
    );
  }
}

/// Single message item
class _MessageItem extends StatefulWidget {
  final Map<String, dynamic> message;

  const _MessageItem({required this.message});

  @override
  State<_MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<_MessageItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final direction = widget.message['direction'] as String? ?? 'incoming';
    final data = widget.message['data'];
    final timestamp = widget.message['timestamp'] as num?;
    final isOutgoing = direction == 'outgoing';

    String displayData;
    bool isJson = false;
    if (data is Map || data is List) {
      displayData = const JsonEncoder.withIndent('  ').convert(data);
      isJson = true;
    } else {
      displayData = data?.toString() ?? '';
      // Try to detect JSON
      if (displayData.trimLeft().startsWith('{') ||
          displayData.trimLeft().startsWith('[')) {
        try {
          final decoded = json.decode(displayData);
          displayData = const JsonEncoder.withIndent('  ').convert(decoded);
          isJson = true;
        } catch (_) {}
      }
    }

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOutgoing
              ? AppColors.methodPost.withOpacity(0.05)
              : AppColors.methodGet.withOpacity(0.05),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
            left: BorderSide(
              color: isOutgoing ? AppColors.methodPost : AppColors.methodGet,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: isOutgoing ? AppColors.methodPost : AppColors.methodGet,
                ),
                const SizedBox(width: 8),
                Text(
                  isOutgoing ? 'Sent' : 'Received',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isOutgoing ? AppColors.methodPost : AppColors.methodGet,
                  ),
                ),
                const SizedBox(width: 8),
                if (isJson)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'JSON',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _isExpanded
                  ? displayData
                  : (displayData.length > 200
                      ? '${displayData.substring(0, 200)}...'
                      : displayData),
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 11),
            ),
            if (displayData.length > 200 && !_isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap to expand',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(num timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// Providers
// ============================================================================

/// State for WebSocket connections
class WebSocketState {
  final List<Map<String, dynamic>> connections;

  const WebSocketState({this.connections = const []});

  WebSocketState copyWith({List<Map<String, dynamic>>? connections}) {
    return WebSocketState(connections: connections ?? this.connections);
  }
}

/// Controller for WebSocket state
class WebSocketController extends StateNotifier<WebSocketState> {
  WebSocketController() : super(const WebSocketState());

  void addConnection(Map<String, dynamic> connection) {
    state = state.copyWith(
      connections: [...state.connections, connection],
    );
  }

  void updateConnection(Map<String, dynamic> connection) {
    final index =
        state.connections.indexWhere((c) => c['id'] == connection['id']);
    if (index != -1) {
      final newConnections = [...state.connections];
      newConnections[index] = connection;
      state = state.copyWith(connections: newConnections);
    }
  }

  void addMessage(String connectionId, Map<String, dynamic> message) {
    final index =
        state.connections.indexWhere((c) => c['id'] == connectionId);
    if (index != -1) {
      final newConnections = [...state.connections];
      final conn = Map<String, dynamic>.from(newConnections[index]);
      final messages = List<Map<String, dynamic>>.from(
        (conn['messages'] as List?) ?? [],
      );
      messages.add(message);
      conn['messages'] = messages;
      newConnections[index] = conn;
      state = state.copyWith(connections: newConnections);
    }
  }

  void clearAll() {
    state = state.copyWith(connections: []);
  }
}

final webSocketControllerProvider =
    StateNotifierProvider<WebSocketController, WebSocketState>((ref) {
  return WebSocketController();
});

final webSocketConnectionsProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(webSocketControllerProvider).connections;
});
