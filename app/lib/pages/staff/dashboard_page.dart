import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/shell.dart';
import '../applicant_dashboard_page.dart' show statusLabel;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  final Session session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _search = TextEditingController();

  String _status = '';
  ApplicationListResult? _result;
  bool _loading = true;
  String? _error;

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _session.api.listApplications(
        status: _status.isEmpty ? null : _status,
        query: _search.text,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String status) {
    setState(() => _status = status);
    _load();
  }

  Future<void> _logout() async {
    await _session.signOut();
    if (mounted) context.go('/staff/login');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final counts = _result?.counts ?? const <String, dynamic>{};

    return AppShell(
      title: 'Applications',
      child: ListView(
        padding: EdgeInsets.all(wide ? 24 : 14),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Welcome, ${_session.staff?.fullName ?? 'Staff'}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${counts['total'] ?? 0} applications in the system',
                      style: const TextStyle(color: TeamakColors.subtle),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => context.go('/staff/messages'),
              icon: const Icon(Icons.mail_outline),
              label: const Text('Contact messages'),
            ),
          ),
          const SizedBox(height: 20),
          _StatsRow(counts: counts),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: wide ? 360 : double.infinity,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: 'Search name, phone, NIN or application no.',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                        ),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _status,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: '', child: Text('All statuses')),
                      DropdownMenuItem<String>(
                        value: 'submitted',
                        child: Text('Submitted'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'pending',
                        child: Text('Under review'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'further_review',
                        child: Text('Further review'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'not_approved',
                        child: Text('Not approved'),
                      ),
                    ],
                    onChanged: (value) => _applyFilter(value ?? ''),
                  ),
                  FilledButton.tonal(onPressed: _load, child: const Text('Refresh')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('$_error', style: TextStyle(color: Colors.red.shade700)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_result == null || _result!.results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No applications match your search.')),
              ),
            )
          else if (wide)
            _ApplicationTable(result: _result!)
          else
            _ApplicationCards(result: _result!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.counts});

  final Map<String, dynamic> counts;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      MapEntry('${counts['submitted'] ?? 0}', 'Submitted'),
      MapEntry('${counts['pending'] ?? 0}', 'Under review'),
      MapEntry('${counts['approved'] ?? 0}', 'Approved'),
      MapEntry('${counts['further_review'] ?? 0}', 'Further review'),
      MapEntry('${counts['not_approved'] ?? 0}', 'Not approved'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    entry.value,
                    style: const TextStyle(color: TeamakColors.subtle),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Color statusColor(String status) => switch (status) {
      'approved' => TeamakColors.primary,
      'not_approved' => Colors.red,
      'further_review' => TeamakColors.accent,
      'pending' => Colors.blueGrey,
      _ => TeamakColors.subtle,
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ApplicationTable extends StatelessWidget {
  const _ApplicationTable({required this.result});

  final ApplicationListResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      // The table takes its intrinsic width and scrolls sideways when that
      // exceeds the card. DataTable squeezes columns to a fixed width, and a
      // heading cell is an unbounded Row — it cannot wrap the way data cells
      // do, so squeezing paints a clipped header rather than scrolling past
      // it. The LayoutBuilder keeps the table filling the card whenever the
      // content is narrower than the viewport.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Application no.')),
                DataColumn(label: Text('Applicant')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Area')),
                DataColumn(label: Text('Programme')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Received')),
              ],
              rows: [
                for (final item in result.results)
                  DataRow(
                    onSelectChanged: (_) =>
                        context.go('/staff/applications/${item.id}'),
                    cells: <DataCell>[
                      DataCell(
                        Text(
                          item.applicationNo,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(item.fullName)),
                      DataCell(Text(item.phoneNumber)),
                      DataCell(Text(item.areaCommunity)),
                      DataCell(Text(item.programmeId)),
                      DataCell(_StatusChip(status: item.status)),
                      DataCell(Text(_shortDate(item.createdAt))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortDate(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;
}

class _ApplicationCards extends StatelessWidget {
  const _ApplicationCards({required this.result});

  final ApplicationListResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in result.results)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/staff/applications/${item.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.applicationNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _StatusChip(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${item.phoneNumber}  •  ${item.areaCommunity}',
                      style: const TextStyle(color: TeamakColors.subtle),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
