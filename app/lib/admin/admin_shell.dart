import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/session.dart';
import '../theme.dart';

/// The eight sections of the administrator console, in the order the sidebar
/// lists them.
class AdminSection {
  const AdminSection(this.path, this.label, this.icon, this.subtitle);

  final String path;
  final String label;
  final IconData icon;

  /// The one-line description the page prints under its title.
  final String subtitle;
}

const List<AdminSection> adminSections = <AdminSection>[
  AdminSection(
    '/admin',
    'Dashboard',
    Icons.space_dashboard_outlined,
    'What is happening across the programme today.',
  ),
  AdminSection(
    '/admin/applicants',
    'Applicants',
    Icons.groups_outlined,
    'Everyone who has applied, and where each one stands.',
  ),
  AdminSection(
    '/admin/pipeline',
    'Pipeline',
    Icons.account_tree_outlined,
    'Applications grouped by the stage they have reached.',
  ),
  AdminSection(
    '/admin/programmes',
    'Programmes',
    Icons.motorcycle_outlined,
    'The ownership tracks on offer and how many riders chose each.',
  ),
  AdminSection(
    '/admin/reports',
    'Reports',
    Icons.insights_outlined,
    'Approvals, deposits and where riders come from.',
  ),
  AdminSection(
    '/admin/messages',
    'Messages',
    Icons.mail_outline,
    'Questions riders and applicants sent through the contact form.',
  ),
  AdminSection(
    '/admin/staff',
    'Staff',
    Icons.badge_outlined,
    'Who can sign in to the review console, and what they can do.',
  ),
  AdminSection(
    '/admin/settings',
    'Settings',
    Icons.settings_outlined,
    'The registered details riders see, and your own account.',
  ),
];

/// The signed-in administrator's console frame: a dark brand sidebar on the
/// wide screen, a drawer on a phone, and a top bar carrying search and the
/// signed-in account.
///
/// Deliberately separate from the public [AppShell]: the public site is a
/// marketing navbar, while this is a working console and needs its section
/// list, badges and account menu always in reach.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.currentPath,
    required this.child,
    this.title,
    this.searchHint,
    this.onSearch,
    this.badges = const <String, int>{},
    this.trailing = const <Widget>[],
  });

  final Session session;

  /// The path being rendered, used to mark the active sidebar entry.
  final String currentPath;

  final Widget child;
  final String? title;

  /// Placeholder in the top-bar search box; the box is hidden when null.
  final String? searchHint;

  /// Called with the typed query when the search box is submitted.
  final ValueChanged<String>? onSearch;

  /// Section path → a count to show as a badge beside that entry.
  final Map<String, int> badges;

  /// Extra buttons for the top bar, after the account menu.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    // The sidebar earns its 250px on a laptop; on a phone the same entries
    // live in the drawer, so the console still fits a 320px screen.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      drawer: wide ? null : Drawer(child: _Sidebar(session: session, currentPath: currentPath, badges: badges)),
      backgroundColor: TeamakColors.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (wide)
            _Sidebar(session: session, currentPath: currentPath, badges: badges),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TopBar(
                  session: session,
                  wide: wide,
                  title: title,
                  searchHint: searchHint,
                  onSearch: onSearch,
                  trailing: trailing,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark brand panel: wordmark, the section list with optional count
/// badges, and the signed-in account pinned to the bottom.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.session,
    required this.currentPath,
    required this.badges,
  });

  final Session session;
  final String currentPath;
  final Map<String, int> badges;

  bool _isActive(String path) =>
      path == currentPath ||
      (path != '/admin' && currentPath.startsWith('$path/'));

  @override
  Widget build(BuildContext context) {
    final staff = session.staff;

    return Container(
      width: 250,
      color: TeamakColors.primaryDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Row(
                children: <Widget>[
                  Icon(Icons.local_shipping_rounded, color: TeamakColors.accent, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TEAMAK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 1.2,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Admin console',
                          style: TextStyle(
                            color: TeamakColors.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: <Widget>[
                  for (final section in adminSections)
                    _SidebarTile(
                      section: section,
                      active: _isActive(section.path),
                      badge: badges[section.path],
                      onTap: () {
                        // A phone reaches the console through the drawer, so
                        // choosing an entry must also close it.
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        context.go(section.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // The account tile gets its own Material: the sidebar paints its
            // navy through a ColoredBox, which would otherwise sit between
            // this tile and the nearest Material and swallow its ink splash.
            Material(
              color: TeamakColors.primaryDark,
              child: ListTile(
                onTap: () => _confirmSignOut(context),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: TeamakColors.accent,
                  child: Text(
                    _initials(staff?.fullName),
                    style: const TextStyle(
                      color: TeamakColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  staff?.fullName ?? 'Administrator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '@${staff?.username ?? 'admin'} · Sign out',
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final wantsOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will return to the sign-in page.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (wantsOut != true || !context.mounted) return;
    await session.signOut();
    if (!context.mounted) return;
    context.go('/staff/login');
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.section,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final AdminSection section;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    // Gold pill when active: the brand accent is the one colour that reads
    // as "selected" against the deep blue panel.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? TeamakColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  section.icon,
                  size: 20,
                  color: active ? TeamakColors.primaryDark : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      color: active ? TeamakColors.primaryDark : Colors.white,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: active ? TeamakColors.primaryDark : TeamakColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        color: active ? TeamakColors.accent : TeamakColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search box plus the signed-in account, sitting above every console page.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.session,
    required this.wide,
    required this.title,
    required this.searchHint,
    required this.onSearch,
    required this.trailing,
  });

  final Session session;
  final bool wide;
  final String? title;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final staff = session.staff;
    final search = searchHint == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: TeamakColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: TeamakColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: TeamakColors.primary),
                ),
              ),
            ),
          );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          if (!wide) ...<Widget>[
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Sections',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
          ] else ...<Widget>[
            if (search != null) search else const Spacer(),
            const Spacer(),
          ],
          ...trailing,
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: staff?.fullName ?? 'Account',
            onSelected: (value) {
              if (value == 'signout') {
                _signOut(context);
              } else if (value == 'public') {
                context.go('/');
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  '${staff?.fullName ?? 'Administrator'} (@${staff?.username ?? 'admin'})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const PopupMenuItem<String>(value: 'public', child: Text('View public site')),
              const PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
            ],
            child: CircleAvatar(
              radius: 16,
              backgroundColor: TeamakColors.primary,
              child: Text(
                _initials(staff?.fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await session.signOut();
    if (!context.mounted) return;
    context.go('/staff/login');
  }
}

/// 'Adebayo Ogundele' → 'AO'; a single word gives its first letter.
String _initials(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'A';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) return first;
  return '$first${parts.last.characters.first.toUpperCase()}';
}

/// The heading every console page prints: title, one-line description and
/// any page-specific actions on the right.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: TeamakColors.subtle, height: 1.4),
        ),
      ],
    );

    if (actions.isEmpty) return heading;
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: heading),
              const SizedBox(width: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
  }
}
