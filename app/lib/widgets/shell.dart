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
    final wide = width >= 720;

    return Scaffold(
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
                  onPressed: () => context.go('/apply'),
                  child: const Text('Apply'),
                ),
                TextButton(
                  onPressed: () => context.go('/contact'),
                  child: const Text('Contact'),
                ),
                TextButton(
                  onPressed: () => context.go('/staff/login'),
                  child: const Text('Staff login'),
                ),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      body: child,
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
