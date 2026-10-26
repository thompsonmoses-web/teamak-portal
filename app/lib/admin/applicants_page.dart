import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// The list of everyone who has applied — the console's "clients" table,
/// with search across the details a reviewer actually recognises.
///
/// Opening a row hands over to the existing staff review page, so the
/// decision workflow, audit trail and official section stay in one place.
class AdminApplicantsPage extends StatefulWidget {
  const AdminApplicantsPage({super.key, required this.session, this.initialQuery});

  final Session session;

  /// Query carried from the top-bar search on the dashboard.
  final String? initialQuery;

  @override
  State<AdminApplicantsPage> createState() => _AdminApplicantsPageState();
}

class _AdminApplicantsPageState extends State<AdminApplicantsPage> {
  late final TextEditingController _search;
  String _status = '';
  ApplicationListResult? _result;
  bool _loading = true;
  String? _error;

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery ?? '');
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
        limit: 200,
      );
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
      currentPath: '/admin/applicants',
      title: 'Applicants',
      searchHint: 'Search applicants…',
      onSearch: (query) {
        _search.text = query;
        _load();
      },
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Applicants',
            subtitle: 'Everyone who has applied, and where each one stands.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: wide ? 380 : double.infinity,
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
                      DropdownMenuItem<String>(value: 'submitted', child: Text('Submitted')),
                      DropdownMenuItem<String>(value: 'pending', child: Text('Under review')),
                      DropdownMenuItem<String>(value: 'approved', child: Text('Approved')),
                      DropdownMenuItem<String>(value: 'further_review', child: Text('Further review')),
                      DropdownMenuItem<String>(value: 'not_approved', child: Text('Not approved')),
                    ],
                    onChanged: (value) {
                      setState(() => _status = value ?? '');
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          else if (results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No applicants match your search.')),
              ),
            )
          else if (wide)
            _ApplicantsTable(results: results)
          else
            _ApplicantsCards(results: results),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ApplicantsTable extends StatelessWidget {
  const _ApplicantsTable({required this.results});

  final List<ApplicationSummary> results;

  @override
  Widget build(BuildContext context) {
    return Card(
      // DataTable squeezes its columns to the available width, so the table
      // takes its intrinsic width and scrolls sideways when a phone cannot
      // hold it. The LayoutBuilder keeps it filling the card when it can.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Applicant')),
                DataColumn(label: Text('Application no.')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Area')),
                DataColumn(label: Text('Programme')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Received')),
              ],
              rows: [
                for (final item in results)
                  DataRow(
                    onSelectChanged: (_) =>
                        context.go('/admin/applicants/${item.id}'),
                    cells: <DataCell>[
                      DataCell(
                        Text(
                          item.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(item.applicationNo)),
                      DataCell(Text(item.phoneNumber)),
                      DataCell(Text(item.areaCommunity)),
                      DataCell(Text(programmeSummary(item.programmeId))),
                      DataCell(StatusChip(status: item.status)),
                      DataCell(Text(shortDate(item.createdAt))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicantsCards extends StatelessWidget {
  const _ApplicantsCards({required this.results});

  final List<ApplicationSummary> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final item in results)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/admin/applicants/${item.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusChip(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.applicationNo} · ${programmeSummary(item.programmeId)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${item.phoneNumber}  ·  ${item.areaCommunity}',
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
