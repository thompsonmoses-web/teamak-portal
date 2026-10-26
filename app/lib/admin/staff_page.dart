import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../pages/staff/team_page.dart' show AddStaffDialog;
import 'admin_shell.dart';
import 'widgets.dart';

/// Who can sign in to the review console, and as what.
///
/// The directory above is the console's "staff" table — a summary each
/// administrator reads at a glance. Every action below it is the existing
/// team management page, so adding an account, changing a role and resetting
/// a password behave exactly as they do at `/staff/team`.
class AdminStaffPage extends StatefulWidget {
  const AdminStaffPage({super.key, required this.session});

  final Session session;

  @override
  State<AdminStaffPage> createState() => _AdminStaffPageState();
}

class _AdminStaffPageState extends State<AdminStaffPage> {
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  Session get _session => widget.session;
  bool get _isAdmin => _session.staff?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isAdmin) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await _session.api.listStaff();
      if (mounted) setState(() => _staff = staff);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.statusCode == 403
            ? 'Administrator access is required.'
            : error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddStaffDialog(api: _session.api),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${created['fullName']} can now sign in as '
            '${created['role'] == 'admin' ? 'an administrator' : 'a reviewer'}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final admins = _staff.where((m) => m['role'] == 'admin').length;
    final reviewers = _staff.length - admins;

    return AdminShell(
      session: _session,
      currentPath: '/admin/staff',
      title: 'Staff',
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Staff',
            subtitle: 'Who can sign in to the review console, and what they can do.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              if (_isAdmin)
                FilledButton.tonalIcon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add team member'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_isAdmin)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Administrator access required',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Only administrators can see and manage staff accounts. '
                      'Ask an administrator to change your role if you need access.',
                      style: TextStyle(color: TeamakColors.subtle, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AdminStatCard(
                    label: 'Administrators',
                    value: '$admins',
                    caption: 'full access, including the team',
                    icon: Icons.admin_panel_settings_outlined,
                    colour: TeamakColors.accentDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    label: 'Reviewers',
                    value: '$reviewers',
                    caption: 'applications and messages',
                    icon: Icons.person_outline,
                    colour: TeamakColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: TeamakColors.danger),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: <Widget>[
                      for (final member in _staff)
                        _StaffRow(
                          member: member,
                          isSelf: member['username'] == _session.staff?.username,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Manage accounts',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a reviewer, change someone’s role or reset a password. '
                      'A password change ends that person’s sessions.',
                      style: TextStyle(color: TeamakColors.subtle, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add team member'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// One directory row: identity, role and the date they joined.
class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.member, required this.isSelf});

  final Map<String, dynamic> member;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final fullName = '${member['fullName']}';
    final username = '${member['username']}';
    final isAdmin = member['role'] == 'admin';
    final joined = '${member['createdAt'] ?? ''}';
    final initials = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isAdmin ? TeamakColors.accent : TeamakColors.primary)
            .withValues(alpha: 0.12),
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: isAdmin ? TeamakColors.accentDark : TeamakColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        isSelf ? '$fullName (you)' : fullName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('@$username${joined.length >= 10 ? ' · joined ${joined.substring(0, 10)}' : ''}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isAdmin ? TeamakColors.accent : TeamakColors.primary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isAdmin ? 'Administrator' : 'Reviewer',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isAdmin ? TeamakColors.accentDark : TeamakColors.primary,
          ),
        ),
      ),
    );
  }
}
