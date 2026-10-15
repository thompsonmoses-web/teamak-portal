import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api/api_client.dart';
import 'pages/apply_page.dart';
import 'pages/contact_page.dart';
import 'pages/landing_page.dart';
import 'pages/receipt_page.dart';
import 'pages/staff/application_detail_page.dart';
import 'pages/staff/dashboard_page.dart';
import 'pages/staff/login_page.dart';
import 'pages/staff/messages_page.dart';
import 'state/session.dart';
import 'theme.dart';

class TeamakApp extends StatefulWidget {
  const TeamakApp({super.key});

  @override
  State<TeamakApp> createState() => _TeamakAppState();
}

class _TeamakAppState extends State<TeamakApp> {
  late final ApiClient _api;
  late final Session _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _session = Session(_api);
    _router = _buildRouter(_session);
    _session.restore();
  }

  GoRouter _buildRouter(Session session) => GoRouter(
        initialLocation: '/',
        refreshListenable: session,
        redirect: (context, state) {
          final location = state.matchedLocation;
          final onStaffArea = location.startsWith('/staff');
          final onLogin = location == '/staff/login';

          if (onStaffArea && !session.restored) return null;
          if (onStaffArea && !session.isSignedIn) return '/staff/login';
          if (onLogin && session.isSignedIn) return '/staff';
          return null;
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const LandingPage(),
          ),
          GoRoute(
            path: '/apply',
            builder: (context, state) => ApplyPage(api: session.api),
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) => ContactPage(api: session.api),
          ),
          GoRoute(
            path: '/receipt',
            builder: (context, state) => ReceiptPage(
              detail: state.extra! as ReceiptDetail,
            ),
          ),
          GoRoute(
            path: '/staff/login',
            builder: (context, state) => LoginPage(session: session),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => DashboardPage(session: session),
          ),
          GoRoute(
            path: '/staff/messages',
            builder: (context, state) => MessagesPage(session: session),
          ),
          GoRoute(
            path: '/staff/applications/:id',
            builder: (context, state) => ApplicationDetailPage(
              api: session.api,
              applicationId: state.pathParameters['id']!,
            ),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(child: Text('Page not found: ${state.uri.path}')),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) => MaterialApp.router(
          title: 'Teamak Global Solutions',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          routerConfig: _router,
        ),
      );
}
