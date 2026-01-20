import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syrah_core/models/models.dart';

import '../../app/theme/app_theme.dart';
import '../home/home_controller.dart';
import '../composer/request_composer.dart';
import 'widgets/headers_view.dart';
import 'widgets/body_viewer.dart';
import 'widgets/timing_chart.dart';

/// Detail panel showing request/response information
class DetailPanel extends ConsumerStatefulWidget {
  const DetailPanel({super.key});

  @override
  ConsumerState<DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends ConsumerState<DetailPanel>
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
    final selectedFlow = ref.watch(selectedFlowProvider);

    if (selectedFlow == null) {
      return const _EmptyState();
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(flow: selectedFlow),
                _RequestTab(flow: selectedFlow),
                _ResponseTab(flow: selectedFlow),
                _TimingTab(flow: selectedFlow),
                _CookiesTab(flow: selectedFlow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Request'),
          Tab(text: 'Response'),
          Tab(text: 'Timing'),
          Tab(text: 'Cookies'),
        ],
      ),
    );
  }
}

/// Empty state when no flow is selected
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Select a request to view details',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
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
          _SectionHeader(
            title: 'General',
            onCopy: () => _copyToClipboard(context, url),
          ),
          const SizedBox(height: 8),
          _InfoRow(label: 'Request URL', value: url),
          _InfoRow(label: 'Request Method', value: method),
          if (statusCode != null)
            _InfoRow(label: 'Status Code', value: '$statusCode $statusMessage'),
          _InfoRow(label: 'Remote Address', value: request.host),
          _InfoRow(label: 'Duration', value: flow.formattedDuration),
          _InfoRow(label: 'Size', value: flow.formattedSize),
          const SizedBox(height: 24),
          // Quick actions
          const _SectionHeader(title: 'Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.code,
                label: 'Copy as cURL',
                onTap: () => _copyCurl(context, request),
              ),
              _ActionChip(
                icon: Icons.replay,
                label: 'Replay Request',
                onTap: () => _replayRequest(context, flow),
              ),
              _ActionChip(
                icon: Icons.edit,
                label: 'Edit & Resend',
                onTap: () => _editAndResend(context, flow),
              ),
              _ActionChip(
                icon: Icons.star_outline,
                label: 'Mark',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyCurl(BuildContext context, HttpRequest request) {
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

    _copyToClipboard(context, buffer.toString());
  }

  void _editAndResend(BuildContext context, NetworkFlow flow) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestComposer(initialFlow: flow),
      ),
    );
  }

  void _replayRequest(BuildContext context, NetworkFlow flow) {
    // Open composer in replay mode (same request, just send)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestComposer(initialFlow: flow),
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
      child: Material(
        color: Colors.transparent,
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
                labelStyle: TextStyle(fontSize: 11),
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
      child: Material(
        color: Colors.transparent,
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
                labelStyle: TextStyle(fontSize: 11),
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
  final VoidCallback? onCopy;

  const _SectionHeader({required this.title, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onCopy != null) ...[
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            onPressed: onCopy,
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action chip button
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
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
                    label: Text('Domain: ${cookie.domain}', style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                if (cookie.path != null)
                  Chip(
                    label: Text('Path: ${cookie.path}', style: const TextStyle(fontSize: 10)),
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
                    label: Text('SameSite: ${cookie.sameSite}', style: const TextStyle(fontSize: 10)),
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
