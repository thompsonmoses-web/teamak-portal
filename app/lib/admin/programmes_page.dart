import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// The ownership tracks on offer and how many riders chose each.
///
/// The tracks come from the same `/programmes` endpoint the apply wizard
/// reads, so a price shown here can never drift from what an applicant was
/// quoted. The counts are tallied from the applications themselves.
class AdminProgrammesPage extends StatefulWidget {
  const AdminProgrammesPage({super.key, required this.session});

  final Session session;

  @override
  State<AdminProgrammesPage> createState() => _AdminProgrammesPageState();
}

class _AdminProgrammesPageState extends State<AdminProgrammesPage> {
  List<Programme> _programmes = const <Programme>[];
  ApplicationListResult? _applications;
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
        _session.api.fetchProgrammes(),
        _session.api.listApplications(limit: 500),
      ]);
      if (!mounted) return;
      setState(() {
        _programmes = results[0] as List<Programme>;
        _applications = results[1] as ApplicationListResult;
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
    final all = _applications?.results ?? const <ApplicationSummary>[];

    return AdminShell(
      session: _session,
      currentPath: '/admin/programmes',
      title: 'Programmes',
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Programmes',
            subtitle: 'The ownership tracks on offer and how many riders chose each.',
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
          else ...<Widget>[
            for (final programme in _programmes) ...<Widget>[
              _ProgrammeCard(
                programme: programme,
                applications: all.where((item) => item.programmeId == programme.id).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({required this.programme, required this.applications});

  final Programme programme;
  final List<ApplicationSummary> applications;

  @override
  Widget build(BuildContext context) {
    final approved =
        applications.where((item) => item.status == 'approved').length;
    final waiting = applications
        .where((item) => item.status == 'submitted' || item.status == 'pending')
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: TeamakColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isMaruwa(programme.id)
                        ? Icons.local_shipping_outlined
                        : Icons.two_wheeler_outlined,
                    color: TeamakColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        programme.label,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${naira(programme.depositNgn)} one-time deposit · '
                        '${programme.months} months',
                        style: const TextStyle(
                          color: TeamakColors.subtle,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              programme.asset,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _CountPill(
                  label: 'applications',
                  count: applications.length,
                  colour: TeamakColors.primary,
                ),
                _CountPill(
                  label: 'awaiting review',
                  count: waiting,
                  colour: TeamakColors.accentDark,
                ),
                _CountPill(
                  label: 'approved',
                  count: approved,
                  colour: TeamakColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.colour,
  });

  final String label;
  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: colour,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
