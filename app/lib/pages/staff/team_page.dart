import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/shell.dart';

/// Administrator-only team management: who can sign in to the staff area,
/// and as what.
///
/// Reviewers never see the button to this page, and one who reaches the URL
/// meets the same wall the API enforces — the guard here decides nothing,
/// it only explains the refusal.
class StaffTeamPage extends StatefulWidget {
  const StaffTeamPage({super.key, required this.session});

  final Session session;

  @override
  State<StaffTeamPage> createState() => _StaffTeamPageState();
}

class _StaffTeamPageState extends State<StaffTeamPage> {
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

  Future<void> _setRole(Map<String, dynamic> member, String role) async {
    try {
      await _session.api.updateStaff(member['id'] as int, role: role);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${member['fullName']} is now '
            '${role == 'admin' ? 'an administrator' : 'a reviewer'}.',
          ),
        ),
      );
    } on ApiException catch (error) {
      // The API refuses the change that would remove the last administrator;
      // its message is the useful part.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> member) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => ResetPasswordDialog(
        name: '${member['fullName']}',
        isSelf: member['username'] == _session.staff?.username,
      ),
    );
    if (password == null || !mounted) return;
    try {
      await _session.api.updateStaff(member['id'] as int, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password updated for ${member['fullName']}.'),
        ),
      );
      // A self-reset ends this session server-side; the next request raises a
      // 401, the session drops and the router returns to the sign-in form —
      // so say so rather than letting the next click look like a failure.
      if (member['username'] == _session.staff?.username) {
        await _session.signOut();
        if (mounted) context.go('/staff/login');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final add = OutlinedButton.icon(
      onPressed: _addMember,
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Add team member'),
    );
    final refresh = OutlinedButton.icon(
      onPressed: _load,
      icon: const Icon(Icons.refresh),
      label: const Text('Refresh'),
    );
    final backToDashboard = OutlinedButton.icon(
      onPressed: () => context.go('/staff'),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Dashboard'),
    );
    final heading = <Widget>[
      const Text(
        'Team',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        _isAdmin
            ? '${_staff.length} staff account'
                '${_staff.length == 1 ? '' : 's'} — '
                'administrators manage applications and the team; '
                'reviewers work through applications and messages.'
            : 'Staff accounts are managed by administrators.',
        style: const TextStyle(color: TeamakColors.subtle),
      ),
    ];

    return AppShell(
      title: 'Team',
      child: ListView(
        padding: EdgeInsets.all(wide ? 24 : 14),
        children: <Widget>[
          if (wide)
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: heading,
                  ),
                ),
                if (_isAdmin) ...<Widget>[add, const SizedBox(width: 8)],
                refresh,
                const SizedBox(width: 8),
                backToDashboard,
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...heading,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (_isAdmin) add,
                    refresh,
                    backToDashboard,
                  ],
                ),
              ],
            ),
          const SizedBox(height: 20),
          if (!_isAdmin)
            const _NoticeCard(
              icon: Icons.lock_outline,
              title: 'Administrator access required',
              body:
                  'Only administrators can see and manage staff accounts. '
                  'Ask an administrator to change your role if you need '
                  'access.',
            )
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _NoticeCard(
              icon: Icons.error_outline,
              title: 'Could not load the team',
              body: _error!,
              action: TextButton(
                onPressed: _load,
                child: const Text('Try again'),
              ),
            )
          else
            for (final member in _staff)
              _StaffTile(
                member: member,
                isSelf: member['username'] == _session.staff?.username,
                onSetRole: (role) => _setRole(member, role),
                onResetPassword: () => _resetPassword(member),
              ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.isSelf,
    required this.onSetRole,
    required this.onResetPassword,
  });

  final Map<String, dynamic> member;
  final bool isSelf;
  final ValueChanged<String> onSetRole;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final fullName = '${member['fullName']}';
    final username = '${member['username']}';
    final isAdmin = member['role'] == 'admin';
    final initials = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    // Identity takes whatever width is left; the menu keeps its 48px, so a
    // 320px screen squeezes only the text — which wraps.
    final identity = Row(
      children: <Widget>[
        CircleAvatar(
          backgroundColor: TeamakColors.primary.withValues(alpha: 0.1),
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: const TextStyle(
              color: TeamakColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isSelf ? '$fullName (you)' : fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                '@$username',
                style: const TextStyle(color: TeamakColors.subtle),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _RoleChip(isAdmin: isAdmin),
                  if (member['createdAt'] != null)
                    Text(
                      'joined ${'${member['createdAt']}'.substring(0, 10)}',
                      style: const TextStyle(
                        color: TeamakColors.dim,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: identity),
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              onSelected: (action) {
                switch (action) {
                  case 'role':
                    onSetRole(isAdmin ? 'reviewer' : 'admin');
                  case 'password':
                    onResetPassword();
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'role',
                  child: ListTile(
                    leading: Icon(
                      isAdmin ? Icons.person_outline : Icons.admin_panel_settings,
                    ),
                    title: Text(
                      isAdmin ? 'Change to reviewer' : 'Make administrator',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'password',
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Reset password'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: TeamakColors.subtle),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: TeamakColors.subtle, height: 1.5),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// The add-account form, as a dialog: four fields, one submit.
///
/// Public because the administrator console manages the same accounts, and
/// one form is the only way the two places can agree on the validation rules.
class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key, required this.api});

  final ApiClient api;

  @override
  State<AddStaffDialog> createState() => AddStaffDialogState();
}

class AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'reviewer';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.api.createStaff(
        username: _username.text.trim(),
        fullName: _name.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // 409 answers the duplicate-username case with its own field error.
        _error = error.statusCode == 409
            ? 'That username is already taken.'
            : error.message;
      });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add team member'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Full name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: '3–32 letters, numbers, dots or dashes',
                  ),
                  validator: (value) => RegExp(r'^[A-Za-z0-9._-]{3,32}$')
                          .hasMatch((value ?? '').trim())
                      ? null
                      : 'Use 3–32 letters, numbers, dots, dashes or '
                          'underscores.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 6 characters',
                  ),
                  validator: (value) => (value ?? '').length >= 6
                      ? null
                      : 'Use at least 6 characters.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'reviewer',
                      child: Text('Reviewer — applications and messages'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'admin',
                      child: Text('Administrator — full access, incl. team'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _role = value ?? 'reviewer'),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: TeamakColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Adding…' : 'Add member'),
        ),
      ],
    );
  }
}

/// Password reset, as a dialog: one field plus the warning that matters.
///
/// Public for the same reason as [AddStaffDialog]: the console and the staff
/// team page must warn about the self-reset identically.
class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({
    super.key,
    required this.name,
    required this.isSelf,
  });

  final String name;
  final bool isSelf;

  @override
  State<ResetPasswordDialog> createState() => ResetPasswordDialogState();
}

class ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset password — ${widget.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 6 characters',
              ),
            ),
            if (widget.isSelf) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'This ends your current sessions — you will sign in again '
                'with the new password.',
                style: TextStyle(
                  color: TeamakColors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final password = _password.text;
            if (password.length >= 6) Navigator.of(context).pop(password);
          },
          child: const Text('Save password'),
        ),
      ],
    );
  }
}
