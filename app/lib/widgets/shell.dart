import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Common page scaffold with the Teamak app bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // The wide app bar now carries two pill buttons alongside four text
    // links, so the drawer takes over below 900px rather than 720px — at
    // 768px the row of actions no longer fits beside the logo and title.
    final wide = width >= 900;

    return Scaffold(
      // Below the wide breakpoint the app bar drops its nav actions entirely,
      // so without a drawer a phone would have no way to reach Apply, Contact
      // or the staff area at all.
      drawer: wide ? null : const _NavDrawer(),
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            const _Logo(),
            const SizedBox(width: 12),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'TEAMAK GLOBAL SOLUTIONS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.1,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'RC No. 9907312',
                      style: TextStyle(
                        color: TeamakColors.subtle,
                        fontSize: 11.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: wide
            ? <Widget>[
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Home'),
                ),
                TextButton(
                  onPressed: () => context.go('/about'),
                  child: const Text('About'),
                ),
                TextButton(
                  onPressed: () => context.go('/what-we-do'),
                  child: const Text('What we do'),
                ),
                TextButton(
                  onPressed: () => context.go('/contact'),
                  child: const Text('Contact'),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => context.go('/staff/login'),
                  child: const Text('Sign In'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.go('/apply'),
                  child: const Text('Apply Now'),
                ),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      body: child,
    );
  }
}

/// Phone navigation. Mirrors the wide-screen app bar actions, which are
/// hidden below the 900px breakpoint.
class _NavDrawer extends StatelessWidget {
  const _NavDrawer();

  static const List<(IconData, String, String)> _destinations =
      <(IconData, String, String)>[
    (Icons.home_outlined, 'Home', '/'),
    (Icons.info_outline, 'About', '/about'),
    (Icons.grid_view_outlined, 'What we do', '/what-we-do'),
    (Icons.groups_outlined, 'Our team', '/team'),
    (Icons.assignment_outlined, 'Apply', '/apply'),
    (Icons.mail_outline, 'Contact', '/contact'),
    (Icons.badge_outlined, 'Staff login', '/staff/login'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  _Logo(),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'TEAMAK GLOBAL\nSOLUTIONS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.15,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable: seven destinations plus the header overrun a short
            // phone, and an unscrollable Column clips the last entry.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final (icon, label, path) in _destinations)
                    ListTile(
                      leading: Icon(icon),
                      title: Text(label),
                      // Closes the drawer before navigating, so the caller does
                      // not land on the new page with the drawer still covering
                      // it.
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(path);
                      },
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(2),
        child: Image.asset(
          'assets/teamak_logo.png',
          height: 36,
          width: 36,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
