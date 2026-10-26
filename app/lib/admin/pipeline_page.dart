import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// Applications grouped by the stage they have reached — the console's view
/// of where the programme currently stands.
///
/// The five columns mirror the statuses the staff review page can set, so a
/// card here always matches what the reviewer sees on the detail page.
class AdminPipelinePage extends StatefulWidget {
  const AdminPipelinePage({super.key, required this.session});

  final Session session;

  @override
  State<AdminPipelinePage> createState() => _AdminPipelinePageState();
}

class _AdminPipelinePageState extends State<AdminPipelinePage> {
  ApplicationListResult? _result;
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
      final result = await _session.api.listApplications(limit: 200);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final results = _result?.results ?? const <ApplicationSummary>[];

    return AdminShell(
      session: _session,
      currentPath: '/admin/pipeline',
      title: 'Pipeline',
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Pipeline',
            subtitle: 'Applications grouped by the stage they have reached.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('$_error', style: const TextStyle(color: TeamakColors.danger)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final status in _stages) ...<Widget>[
              _StageSection(
                status: status,
                items: results.where((item) => item.status == status).toList(),
              ),
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The stages in the order a healthy application moves through them.
const List<String> _stages = <String>[
  'submitted',
  'pending',
  'further_review',
  'approved',
  'not_approved',
];

class _StageSection extends StatelessWidget {
  const _StageSection({required this.status, required this.items});

  final String status;
  final List<ApplicationSummary> items;

  @override
  Widget build(BuildContext context) {
    final colour = statusColour(status);
    final ordered = items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText(status),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: colour,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ordered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Nothing at this stage.',
                  style: TextStyle(color: TeamakColors.subtle),
                ),
              )
            else
              for (final item in ordered)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.go('/admin/applicants/${item.id}'),
                  title: Text(
                    item.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.applicationNo} · ${programmeSummary(item.programmeId)} · '
                    '${item.areaCommunity}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: Text(
                    shortDate(item.createdAt),
                    style: const TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 12,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
