import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api/api_client.dart';
import 'models/models.dart';
import 'pages/about_page.dart';
import 'pages/apply_page.dart';
import 'pages/applicant_dashboard_page.dart';
import 'pages/contact_page.dart';
import 'pages/landing_page.dart';
import 'pages/not_found_page.dart';
import 'pages/staff/application_detail_page.dart';
import 'pages/staff/dashboard_page.dart';
import 'pages/staff/login_page.dart';
import 'pages/staff/messages_page.dart';
import 'pages/staff/team_page.dart';
import 'pages/team_page.dart';
import 'pages/what_we_do_page.dart';
import 'state/session.dart';
import 'theme.dart';

class TeamakApp extends StatefulWidget {
  const TeamakApp({super.key, this.initialPath = '/', this.api});

  /// Route to open first, so tests can target a single page.
  final String initialPath;

  /// Client the app talks to the server through.
  ///
  /// Tests inject a stand-in here: the staff area is unreachable otherwise,
  /// because the router bounces every `/staff` route to sign-in until a
  /// session exists, and a session needs an answer from the API.
  final ApiClient? api;

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
    _api = widget.api ?? ApiClient();
    _session = Session(_api);
    _router = _buildRouter(_session);
    _session.restore();
  }

  GoRouter _buildRouter(Session session) => GoRouter(
        initialLocation: widget.initialPath,
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
            path: '/about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: '/what-we-do',
            builder: (context, state) => const WhatWeDoPage(),
          ),
          GoRoute(
            path: '/team',
            builder: (context, state) => const TeamPage(),
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
            path: '/dashboard',
            // `extra` is the wizard's fresh submission. On a refresh or a
            // cold visit it is null, and the page falls back to the pair
            // stored on the device — or the tracking form if there is none.
            builder: (context, state) => ApplicantDashboardPage(
              api: session.api,
              detail: state.extra is ApplicationDetail
                  ? state.extra! as ApplicationDetail
                  : null,
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
          GoRoute(
            path: '/staff/team',
            builder: (context, state) => StaffTeamPage(session: session),
          ),
        ],
        errorBuilder: (context, state) =>
            NotFoundPage(requestedPath: state.uri.path),
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
