import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin/applicants_page.dart';
import 'admin/dashboard_page.dart';
import 'admin/messages_page.dart';
import 'admin/pipeline_page.dart';
import 'admin/programmes_page.dart';
import 'admin/reports_page.dart';
import 'admin/settings_page.dart';
import 'admin/staff_page.dart';
import 'api/api_client.dart';
import 'models/models.dart';
import 'pages/about_page.dart';
import 'pages/apply_page.dart';
import 'pages/applicant_dashboard_page.dart';
import 'pages/contact_page.dart';
import 'pages/faq_page.dart';
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
          final onAdminArea = location.startsWith('/admin');

          if (onStaffArea && !session.restored) return null;
          if (onStaffArea && !session.isSignedIn) return '/staff/login';
          // The console is a working area holding every applicant's details,
          // so it waits for a restored session and then for a signed-in
          // administrator. A reviewer who reaches the URL is held at the
          // sign-in form — the pages explain the refusal if one gets through.
          if (onAdminArea && !session.restored) return null;
          if (onAdminArea && !session.isSignedIn) return '/staff/login';
          if (onAdminArea && session.staff?.role != 'admin') {
            return '/staff';
          }
          // An administrator lands on the console; everyone else on the
          // applications list they work through.
          if (onLogin && session.isSignedIn) {
            return session.staff?.role == 'admin' ? '/admin' : '/staff';
          }
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
            path: '/faq',
            builder: (context, state) => const FaqPage(),
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
              // A shared tracking link carries the number so the form
              // opens with it filled in; the phone check still stands.
              prefillNumber: state.uri.queryParameters['no'],
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

          // ── Administrator console ────────────────────────────────────
          // A separate frame from the staff area: the sidebar console carries
          // the whole programme, so it sits beside /staff rather than inside
          // it. Every page is reached only through the admin guard above.
          GoRoute(
            path: '/admin',
            builder: (context, state) =>
                AdminDashboardPage(session: session),
          ),
          GoRoute(
            path: '/admin/applicants',
            builder: (context, state) => AdminApplicantsPage(
              session: session,
              // The top-bar search on the dashboard carries its query here.
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: '/admin/applicants/:id',
            // One review page for the whole portal: the console opens the
            // same application the staff area does, so a decision is made in
            // one place whichever door it was reached through.
            builder: (context, state) => ApplicationDetailPage(
              api: session.api,
              applicationId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/pipeline',
            builder: (context, state) =>
                AdminPipelinePage(session: session),
          ),
          GoRoute(
            path: '/admin/programmes',
            builder: (context, state) =>
                AdminProgrammesPage(session: session),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) =>
                AdminReportsPage(session: session),
          ),
          GoRoute(
            path: '/admin/messages',
            builder: (context, state) =>
                AdminMessagesPage(session: session),
          ),
          GoRoute(
            path: '/admin/staff',
            builder: (context, state) =>
                AdminStaffPage(session: session),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) =>
                AdminSettingsPage(session: session),
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
          // The Pages preview states what it is on every screen — nobody
          // should mistake a browser-stored demo application for a real one.
          builder: (context, child) => Column(
            children: <Widget>[
              if (const String.fromEnvironment('API_BASE') == demoApiBase)
                const _PreviewBanner(),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
}

/// Gold strip shown above every screen in the Pages preview build.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) => Material(
        color: TeamakColors.accent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Preview build — applications and sign-ins are stored only in '
              'this browser; nothing reaches a Teamak server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: TeamakColors.primaryDark,
              ),
            ),
          ),
        ),
      );
}
