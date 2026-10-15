import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/shell.dart';

/// Shown for any URL that matches no route.
///
/// It sits in [AppShell] rather than a bare Scaffold on purpose: below the
/// 720px breakpoint the shell owns the drawer, so a phone user who lands on a
/// dead link still has a way to Apply, Contact or sign in — and the two
/// buttons below give a direct route out for everyone else.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.requestedPath});

  /// The path that matched nothing, so the message can name it.
  final String requestedPath;

  @override
  Widget build(BuildContext context) {
    final path = requestedPath.isEmpty ? '/' : requestedPath;

    return AppShell(
      title: 'Page not found',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '404',
                  style: TextStyle(
                    fontSize: 76,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: TeamakColors.primary,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We can’t find that page',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'No screen matches “$path”. The link may be out of date, or '
                  'the page may have moved.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TeamakColors.subtle),
                ),
                const SizedBox(height: 26),
                // Wrapped: on a 320px phone these two buttons side by side
                // would not fit, and stacking keeps both usable.
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Back to home'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/apply'),
                      icon: const Icon(Icons.edit_document),
                      label: const Text('Start application'),
                    ),
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
