import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// Approval, deposit and origin breakdowns, counted straight from the
/// application records the API already holds.
///
/// Nothing here is estimated: the approval rate is applications decided
/// approved against all applications, and the deposit figure is the sum of
/// the one-time deposits for approved applications — not money received,
/// which this portal does not track.
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key, required this.session});

  final Session session;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  ApplicationListResult? _result;
  List<Programme> _programmes = const <Programme>[];
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
        _session.api.listApplications(limit: 500),
        _session.api.fetchProgrammes(),
      ]);
      if (!mounted) return;
      setState(() {
        _result = results[0] as ApplicationListResult;
        _programmes = results[1] as List<Programme>;
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
    final all = _result?.results ?? const <ApplicationSummary>[];
    final counts = _result?.counts ?? const <String, dynamic>{};

    int count(String key) => (counts[key] as num? ?? 0).toInt();
    final approved = count('approved');
    final total = count('total');
    final rate = total == 0 ? 0 : (approved * 100 / total).round();

    // The one-time deposit each approved application covers, priced from the
    // same list the apply wizard quotes.
    final depositByProgramme = <String, int>{
      for (final programme in _programmes) programme.id: programme.depositNgn,
    };
    var depositTotal = 0;
    for (final item in all) {
      if (item.status != 'approved') continue;
      depositTotal += depositByProgramme[item.programmeId] ?? 0;
    }

    // Where riders come from, by the area they gave.
    final byArea = <String, int>{};
    for (final item in all) {
      final area = item.areaCommunity.trim();
      if (area.isEmpty) continue;
      byArea[area] = (byArea[area] ?? 0) + 1;
    }
    final areas = byArea.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AdminShell(
      session: _session,
      currentPath: '/admin/reports',
      title: 'Reports',
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Reports',
            subtitle: 'Approvals, deposits and where riders come from.',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AdminStatCard(
                    label: 'Approval rate',
                    value: '$rate%',
                    caption: '$approved of $total applications',
                    icon: Icons.verified_outlined,
                    colour: TeamakColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    label: 'Deposits covered by approvals',
                    value: naira(depositTotal),
                    caption: 'one-time deposits, not payments received',
                    icon: Icons.savings_outlined,
                    colour: TeamakColors.accentDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BreakdownCard(
              title: 'Applications by stage',
              subtitle: 'Every application, by where it stands today.',
              rows: <(String, int, Color)>[
                ('Submitted', count('submitted'), statusColour('submitted')),
                ('Under review', count('pending'), statusColour('pending')),
                ('Further review', count('further_review'), statusColour('further_review')),
                ('Approved', approved, statusColour('approved')),
                ('Not approved', count('not_approved'), statusColour('not_approved')),
              ],
              total: total,
            ),
            const SizedBox(height: 16),
            _BreakdownCard(
              title: 'Applications by programme',
              subtitle: 'Which ownership track riders are choosing.',
              rows: <(String, int, Color)>[
                for (final programme in _programmes)
                  (
                    programme.label,
                    all.where((item) => item.programmeId == programme.id).length,
                    isMaruwa(programme.id)
                        ? TeamakColors.accentDark
                        : TeamakColors.primary,
                  ),
              ],
              total: total,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Applicants by area',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Where riders told us they live and operate.',
                      style: TextStyle(color: TeamakColors.subtle, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (areas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No applications yet.',
                          style: TextStyle(color: TeamakColors.subtle),
                        ),
                      )
                    else
                      for (final entry in areas)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: total == 0 ? 0 : entry.value / total,
                                    minHeight: 8,
                                    backgroundColor: TeamakColors.surface3,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      TeamakColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${entry.value}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// A titled card listing a share bar per row, each sized against the total.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.total,
  });

  final String title;
  final String subtitle;
  final List<(String, int, Color)> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: TeamakColors.subtle, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No applications yet.',
                  style: TextStyle(color: TeamakColors.subtle),
                ),
              )
            else
              for (final (label, count, colour) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colour,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: count / total,
                            minHeight: 8,
                            backgroundColor: TeamakColors.surface3,
                            valueColor: AlwaysStoppedAnimation<Color>(colour),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
