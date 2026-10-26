import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// The administrator's landing page: the four numbers that matter, the newest
/// applications, the queue waiting on a decision, and the messages riders
/// sent.
///
/// Every figure on this page is counted from the records the API already
/// returns — nothing here is estimated or invented.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.session});

  final Session session;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  ApplicationListResult? _applications;
  List<ContactMessage> _messages = const <ContactMessage>[];
  bool _loading = true;
  String? _error;

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(<Future<Object?>>[
        _session.api.listApplications(limit: 200),
        _session.api.fetchMessages(),
      ]);
      if (!mounted) return;
      setState(() {
        _applications = results[0] as ApplicationListResult;
        _messages = results[1] as List<ContactMessage>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final counts = _applications?.counts ?? const <String, dynamic>{};
    final review = (counts['submitted'] as num? ?? 0).toInt() +
        (counts['pending'] as num? ?? 0).toInt();
    final padding = EdgeInsets.all(wide ? 26 : 16);

    return AdminShell(
      session: _session,
      currentPath: '/admin',
      title: 'Dashboard',
      searchHint: 'Search applicants, phone or application number…',
      onSearch: (query) =>
          context.go('/admin/applicants?q=${Uri.encodeComponent(query)}'),
      badges: <String, int>{
        '/admin/pipeline': review,
        '/admin/messages': _messages.length,
      },
      child: ListView(
        padding: padding,
        children: <Widget>[
          AdminPageHeader(
            title: 'Dashboard',
            subtitle: 'Here is what is happening across the programme.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/admin/applicants'),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('All applicants'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null) ...<Widget>[
            _ErrorCard(message: _error!, onRetry: _load),
            const SizedBox(height: 20),
          ],
          if (_loading && _applications == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            _StatRow(counts: counts, messageCount: _messages.length),
            const SizedBox(height: 20),
            _PendingPanel(
              applications: _applications,
              review: review,
              onOpen: (item) => context.go('/admin/applicants/${item.id}'),
              onSeeAll: () => context.go('/admin/pipeline'),
            ),
            const SizedBox(height: 20),
            _RecentApplications(
              applications: _applications,
              onOpen: (item) => context.go('/admin/applicants/${item.id}'),
              onSeeAll: () => context.go('/admin/applicants'),
            ),
            const SizedBox(height: 20),
            _RecentMessages(
              messages: _messages,
              onSeeAll: () => context.go('/admin/messages'),
            ),
            const SizedBox(height: 20),
            _QuickActionsCard(
              onApplicants: () => context.go('/admin/applicants'),
              onMessages: () => context.go('/admin/messages'),
              onStaff: () => context.go('/admin/staff'),
              onPublicSite: () => context.go('/'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The four headline numbers plus the messages count.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.counts, required this.messageCount});

  final Map<String, dynamic> counts;
  final int messageCount;

  int _count(String key) => (counts[key] as num? ?? 0).toInt();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final mid = MediaQuery.sizeOf(context).width >= 640;

    final cards = <Widget>[
      AdminStatCard(
        label: 'Total applicants',
        value: '${_count('total')}',
        icon: Icons.groups_outlined,
        colour: TeamakColors.primary,
      ),
      AdminStatCard(
        label: 'Awaiting review',
        value: '${_count('submitted') + _count('pending')}',
        icon: Icons.pending_actions_outlined,
        colour: TeamakColors.accentDark,
      ),
      AdminStatCard(
        label: 'Approved',
        value: '${_count('approved')}',
        icon: Icons.verified_outlined,
        colour: TeamakColors.primary,
      ),
      AdminStatCard(
        label: 'Messages',
        value: '$messageCount',
        icon: Icons.mail_outline,
        colour: TeamakColors.primary,
      ),
    ];

    if (wide) {
      return Row(
        children: <Widget>[
          for (var i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    if (mid) {
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: <Widget>[
          for (final card in cards)
            SizedBox(width: (MediaQuery.sizeOf(context).width - 60) / 2, child: card),
        ],
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}

/// Everything waiting on a staff decision, listed newest first — the queue
/// an administrator clears first thing.
class _PendingPanel extends StatelessWidget {
  const _PendingPanel({
    required this.applications,
    required this.review,
    required this.onOpen,
    required this.onSeeAll,
  });

  final ApplicationListResult? applications;
  final int review;
  final ValueChanged<ApplicationSummary> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final waiting = (applications?.results ?? const <ApplicationSummary>[])
        .where((item) => item.status == 'submitted' || item.status == 'pending')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = waiting.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Waiting for a decision',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '$review in the queue',
                  style: const TextStyle(
                    color: TeamakColors.subtle,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'Nothing is waiting — every application has been decided.',
                    style: TextStyle(color: TeamakColors.subtle),
                  ),
                ),
              )
            else ...<Widget>[
              for (final item in shown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => onOpen(item),
                  leading: CircleAvatar(
                    backgroundColor: TeamakColors.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.person_outline,
                      color: TeamakColors.primary,
                    ),
                  ),
                  title: Text(
                    item.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.applicationNo} · ${item.areaCommunity}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSeeAll,
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: const Text('See the whole pipeline'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The newest applications whatever their status, so an administrator sees
/// fresh arrivals without opening the applicants table.
class _RecentApplications extends StatelessWidget {
  const _RecentApplications({
    required this.applications,
    required this.onOpen,
    required this.onSeeAll,
  });

  final ApplicationListResult? applications;
  final ValueChanged<ApplicationSummary> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final recent = (applications?.results ?? const <ApplicationSummary>[])
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = recent.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Newest applications',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: onSeeAll,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'No applications yet.',
                    style: TextStyle(color: TeamakColors.subtle),
                  ),
                ),
              )
            else
              for (final item in shown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => onOpen(item),
                  title: Text(
                    item.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.applicationNo} · ${programmeSummary(item.programmeId)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: StatusChip(status: item.status),
                ),
          ],
        ),
      ),
    );
  }
}

/// The three newest contact-form messages.
class _RecentMessages extends StatelessWidget {
  const _RecentMessages({required this.messages, required this.onSeeAll});

  final List<ContactMessage> messages;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final recent = messages.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Latest messages',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: onSeeAll,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: TeamakColors.subtle),
                  ),
                ),
              )
            else
              for (final message in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: onSeeAll,
                  leading: const CircleAvatar(
                    backgroundColor: TeamakColors.surface2,
                    child: Icon(Icons.mail_outline, color: TeamakColors.primary),
                  ),
                  title: Text(
                    message.subject.isEmpty ? 'General enquiry' : message.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${message.name} · ${message.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onApplicants,
    required this.onMessages,
    required this.onStaff,
    required this.onPublicSite,
  });

  final VoidCallback onApplicants;
  final VoidCallback onMessages;
  final VoidCallback onStaff;
  final VoidCallback onPublicSite;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Quick actions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onApplicants,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Review applicants'),
                ),
                OutlinedButton.icon(
                  onPressed: onMessages,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Read messages'),
                ),
                OutlinedButton.icon(
                  onPressed: onStaff,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Manage staff'),
                ),
                OutlinedButton.icon(
                  onPressed: onPublicSite,
                  icon: const Icon(Icons.public),
                  label: const Text('View public site'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Could not load the dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: TeamakColors.subtle)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
