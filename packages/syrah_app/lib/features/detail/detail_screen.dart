import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syrah_core/models/models.dart';

import '../../app/theme/app_theme.dart';
import '../home/home_controller.dart';
import '../composer/request_composer.dart';
import 'widgets/headers_view.dart';
import 'widgets/body_viewer.dart';
import 'widgets/timing_chart.dart';

/// Full-screen detail screen for mobile (push navigation)
class DetailScreen extends ConsumerStatefulWidget {
  final String flowId;

  const DetailScreen({
    super.key,
    required this.flowId,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Find the flow by ID
    final flows = ref.watch(filteredFlowsProvider);
    final flow = flows.firstWhere(
      (f) => f.id == widget.flowId,
      orElse: () => flows.isNotEmpty ? flows.first : _createEmptyFlow(),
    );

    // Handle empty state
    if (flows.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Request Details'),
        ),
        body: const Center(
          child: Text('No request selected'),
        ),
      );
    }

    final request = flow.request;
    final response = flow.response;
    final method = request.method.name.toUpperCase();
    final statusCode = response?.statusCode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MethodBadge(method: method),
                const SizedBox(width: 8),
                if (statusCode != null)
                  Text(
                    '$statusCode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusColor(statusCode),
                    ),
                  ),
              ],
            ),
            Text(
              request.host,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Mark/star
          IconButton(
            icon: Icon(
              flow.isMarked ? Icons.star : Icons.star_border,
              color: flow.isMarked ? AppColors.warning : null,
            ),
            onPressed: () =>
                ref.read(homeControllerProvider.notifier).toggleMark(flow.id),
            tooltip: flow.isMarked ? 'Unmark' : 'Mark',
          ),
          // Share/export
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_curl',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 18),
                    SizedBox(width: 12),
                    Text('Copy as cURL'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_url',
                child: Row(
                  children: [
                    Icon(Icons.link, size: 18),
                    SizedBox(width: 12),
                    Text('Copy URL'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'replay',
                child: Row(
                  children: [
                    Icon(Icons.replay, size: 18),
                    SizedBox(width: 12),
                    Text('Replay'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_resend',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 12),
                    Text('Edit & Resend'),
                  ],
                ),
              ),
            ],
            onSelected: (value) => _handleMenuAction(value, flow),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Request'),
            Tab(text: 'Response'),
            Tab(text: 'Timing'),
            Tab(text: 'Cookies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(flow: flow),
          _RequestTab(flow: flow),
          _ResponseTab(flow: flow),
          _TimingTab(flow: flow),
          _CookiesTab(flow: flow),
        ],
      ),
    );
  }

  NetworkFlow _createEmptyFlow() {
    // Return a minimal flow for edge cases
    return NetworkFlow(
      id: '',
      sessionId: '',
      request: HttpRequest(
        id: '',
        method: HttpMethod.get,
        url: '',
        scheme: 'http',
        host: '',
        port: 80,
        path: '',
        headers: {},
        contentType: ContentType.unknown,
        contentLength: 0,
        httpVersion: HttpVersion.http1_1,
        timestamp: DateTime.now(),
        isSecure: false,
      ),
      state: FlowState.pending,
      protocol: ProtocolType.http,
      webSocketMessages: [],
      tags: [],
      isMarked: false,
      matchesFilter: false,
      appliedRules: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sequenceNumber: 0,
    );
  }

  void _handleMenuAction(String action, NetworkFlow flow) {
    switch (action) {
      case 'copy_curl':
        _copyCurl(flow.request);
        break;
      case 'copy_url':
        _copyToClipboard(flow.request.url);
        break;
      case 'replay':
      case 'edit_resend':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RequestComposer(initialFlow: flow),
          ),
        );
        break;
    }
  }

  void _copyCurl(HttpRequest request) {
    final method = request.method.name.toUpperCase();
    final url = request.url;
    final headers = request.headers;

    final buffer = StringBuffer('curl');
    if (method != 'GET') {
      buffer.write(' -X $method');
    }

    headers.forEach((key, value) {
      buffer.write(" -H '$key: $value'");
    });

    final body = request.bodyText;
    if (body != null && body.isNotEmpty) {
      buffer.write(" -d '$body'");
    }

    buffer.write(" '$url'");

    _copyToClipboard(buffer.toString());
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Method badge widget
class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.methodColor(method).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.methodColor(method),
        ),
      ),
    );
  }
}

/// Overview tab showing summary information
class _OverviewTab extends StatelessWidget {
  final NetworkFlow flow;

  const _OverviewTab({required this.flow});

  @override
  Widget build(BuildContext context) {
    final request = flow.request;
    final response = flow.response;

    final method = request.method.name.toUpperCase();
    final url = request.url;
    final statusCode = response?.statusCode;
    final statusMessage = response?.statusMessage ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL and method
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.methodColor(method).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.methodColor(method),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (statusCode != null) ...[
                Text(
                  '$statusCode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusColor(statusCode),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Full URL
          SelectableText(
            url,
            style: Theme.of(context).textTheme.code.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 24),
          // General info
          const _SectionHeader(title: 'General'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Request URL', value: url),
          _InfoRow(label: 'Request Method', value: method),
          if (statusCode != null)
            _InfoRow(label: 'Status Code', value: '$statusCode $statusMessage'),
          _InfoRow(label: 'Remote Address', value: request.host),
          _InfoRow(label: 'Duration', value: flow.formattedDuration),
          _InfoRow(label: 'Size', value: flow.formattedSize),
        ],
      ),
    );
  }
}

/// Request tab showing request headers and body
class _RequestTab extends StatelessWidget {
  final NetworkFlow flow;

  const _RequestTab({required this.flow});

  @override
  Widget build(BuildContext context) {
    final request = flow.request;
    final headers = request.headers;
    final body = request.bodyText;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: TextStyle(fontSize: 13),
              tabs: [
                Tab(text: 'Headers'),
                Tab(text: 'Body'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                HeadersView(headers: headers),
                BodyViewer(body: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Response tab showing response headers and body
class _ResponseTab extends StatelessWidget {
  final NetworkFlow flow;

  const _ResponseTab({required this.flow});

  @override
  Widget build(BuildContext context) {
    final response = flow.response;
    if (response == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text('Waiting for response...'),
          ],
        ),
      );
    }

    final headers = response.headers;
    final body = response.bodyText;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: TextStyle(fontSize: 13),
              tabs: [
                Tab(text: 'Headers'),
                Tab(text: 'Body'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                HeadersView(headers: headers),
                BodyViewer(body: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Timing tab showing request/response timing
class _TimingTab extends StatelessWidget {
  final NetworkFlow flow;

  const _TimingTab({required this.flow});

  @override
  Widget build(BuildContext context) {
    return TimingChart(flow: flow);
  }
}

/// Cookies tab showing request and response cookies
class _CookiesTab extends StatelessWidget {
  final NetworkFlow flow;

  const _CookiesTab({required this.flow});

  @override
  Widget build(BuildContext context) {
    final request = flow.request;
    final response = flow.response;

    final requestCookies = request.cookies;
    final responseCookies = response?.cookies ?? [];

    if (requestCookies.isEmpty && responseCookies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cookie_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No cookies',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (requestCookies.isNotEmpty) ...[
            const _SectionHeader(title: 'Request Cookies'),
            const SizedBox(height: 8),
            ...requestCookies.entries.map(
              (e) => _InfoRow(label: e.key, value: e.value),
            ),
            const SizedBox(height: 24),
          ],
          if (responseCookies.isNotEmpty) ...[
            const _SectionHeader(title: 'Response Cookies'),
            const SizedBox(height: 8),
            ...responseCookies.map((cookie) => _SetCookieCard(cookie: cookie)),
          ],
        ],
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Info row widget for key-value pairs
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Set-Cookie card widget
class _SetCookieCard extends StatelessWidget {
  final SetCookie cookie;

  const _SetCookieCard({required this.cookie});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cookie.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SelectableText(
              cookie.value,
              style: Theme.of(context).textTheme.code,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (cookie.domain != null)
                  Chip(
                    label: Text('Domain: ${cookie.domain}',
                        style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                if (cookie.path != null)
                  Chip(
                    label: Text('Path: ${cookie.path}',
                        style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                if (cookie.secure)
                  const Chip(
                    label: Text('Secure', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                if (cookie.httpOnly)
                  const Chip(
                    label: Text('HttpOnly', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                if (cookie.sameSite != null)
                  Chip(
                    label: Text('SameSite: ${cookie.sameSite}',
                        style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
