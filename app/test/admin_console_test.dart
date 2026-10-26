import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/app.dart';

/// The console is a working area holding every applicant's details, so the
/// rules that decide who reaches it are worth pinning down: an administrator
/// gets in, a reviewer is turned away at the door, and nobody gets in without
/// signing in first.
///
/// The responsive sweep proves the pages fit; this proves the guard sends the
/// right people to the right place.
void main() {
  /// Serves a session for [role] plus the records the console reads, so a
  /// page that loads renders real content rather than an empty shell.
  ApiClient apiFor(String role) => ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          final String body;
          if (path == '/auth/login') {
            body = '{"token":"stored-token","staff":{"username":"$role",'
                '"fullName":"Portal ${_capital(role)}","role":"$role"}}';
          } else if (path == '/auth/me') {
            body = '{"username":"$role","fullName":"Portal ${_capital(role)}",'
                '"role":"$role"}';
          } else if (path == '/applications') {
            body = _applications;
          } else if (path.startsWith('/applications/')) {
            body = _application;
          } else if (path == '/contact') {
            body = _messages;
          } else if (path == '/programmes') {
            body = _programmes;
          } else if (path == '/staff') {
            body = _staff;
          } else {
            body = '{}';
          }
          return http.Response(
            body,
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

  /// Pumps the app at [path] with a stored token, so the router's guard
  /// decides the outcome rather than the absence of a session.
  Future<void> openAt(
    WidgetTester tester,
    String path, {
    required String role,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'teamak_staff_token': 'stored-token',
    });
    await tester.pumpWidget(
      TeamakApp(initialPath: path, api: apiFor(role)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an administrator reaches the console', (tester) async {
    await openAt(tester, '/admin', role: 'admin');

    expect(find.text('Dashboard'), findsWidgets);
    expect(
      find.text('Waiting for a decision'),
      findsOneWidget,
      reason: 'the console should render its real panels for an admin',
    );
  });

  testWidgets('an administrator signing in lands on the console',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      TeamakApp(initialPath: '/staff/login', api: apiFor('admin')),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextFormField).first, 'admin');
    await tester.enterText(find.byType(TextFormField).last, 'secret1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Waiting for a decision'),
      findsOneWidget,
      reason: 'an administrator should land on the console, not the list',
    );
  });

  testWidgets('a reviewer is sent back to the staff area', (tester) async {
    await openAt(tester, '/admin', role: 'reviewer');

    expect(
      find.text('Waiting for a decision'),
      findsNothing,
      reason: 'a reviewer must not see the console overview',
    );
    expect(
      find.text('Applications'),
      findsWidgets,
      reason: 'a reviewer belongs on the applications list they work through',
    );
  });

  testWidgets('a reviewer is redirected away from every console section',
      (tester) async {
    for (final section in <String>[
      '/admin/applicants',
      '/admin/pipeline',
      '/admin/reports',
      '/admin/staff',
    ]) {
      await openAt(tester, section, role: 'reviewer');

      expect(
        find.text('Waiting for a decision'),
        findsNothing,
        reason: '$section should not render for a reviewer',
      );
    }
  });

  testWidgets('a signed-out visitor is held at the sign-in form',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      TeamakApp(initialPath: '/admin', api: apiFor('admin')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Sign in'),
      findsWidgets,
      reason: 'the console must never render without a session',
    );
    expect(find.text('Waiting for a decision'), findsNothing);
  });

  testWidgets('the console counts come from the records, not decoration',
      (tester) async {
    await openAt(tester, '/admin', role: 'admin');

    // The fixture holds three applications, one of them awaiting review.
    expect(find.text('3'), findsWidgets, reason: 'total applicants');
    expect(
      find.text('Adebayo Ogundele'),
      findsWidgets,
      reason: 'the waiting queue and the newest list both name real applicants',
    );
  });

  testWidgets('the pipeline groups applications by stage', (tester) async {
    await openAt(tester, '/admin/pipeline', role: 'admin');

    expect(find.text('Under review'), findsWidgets);

    // The stages stack vertically and the list builds lazily, so the later
    // sections only exist once they have been scrolled into view.
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('Approved'), findsWidgets);
    expect(find.text('Folake Adeyemi'), findsOneWidget);
  });

  testWidgets('reports read their figures from the same records',
      (tester) async {
    await openAt(tester, '/admin/reports', role: 'admin');

    // One of three applications is approved → 33%.
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1 of 3 applications'), findsOneWidget);
  });

  testWidgets('the console signs out back to the sign-in form', (tester) async {
    await openAt(tester, '/admin', role: 'admin');

    // The account menu in the top bar carries the sign-out entry. The type
    // argument matters: byType matches the widget's exact runtime type, and
    // the account menu is a PopupMenuButton<String>.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in'),
      findsWidgets,
      reason: 'signing out must leave the console immediately',
    );
  });
}

String _capital(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

const String _applications = '''
{
  "total": 3,
  "counts": {
    "submitted": 0,
    "pending": 1,
    "approved": 1,
    "further_review": 0,
    "not_approved": 1,
    "total": 3
  },
  "results": [
    {
      "id": "1",
      "applicationNo": "TRP-2026-0042",
      "status": "pending",
      "fullName": "Adebayo Ogundele",
      "phoneNumber": "08023449126",
      "programmeId": "okada_650",
      "areaCommunity": "Ojoo, Ibadan",
      "createdAt": "2026-10-02T09:14:00Z",
      "official": {"verificationStatus": "unverified"}
    },
    {
      "id": "2",
      "applicationNo": "TRP-2026-0039",
      "status": "approved",
      "fullName": "Folake Adeyemi",
      "phoneNumber": "08031234567",
      "programmeId": "okada_400",
      "areaCommunity": "Aba Opa, Ibadan",
      "createdAt": "2026-09-28T14:02:00Z",
      "official": {"verificationStatus": "verified"}
    },
    {
      "id": "3",
      "applicationNo": "TRP-2026-0035",
      "status": "not_approved",
      "fullName": "Sunday Balogun",
      "phoneNumber": "08055556666",
      "programmeId": "maruwa_2300",
      "areaCommunity": "Oluyole, Ibadan",
      "createdAt": "2026-09-21T08:45:00Z",
      "official": {"verificationStatus": "failed"}
    }
  ]
}
''';

const String _application = '''
{
  "id": "1",
  "applicationNo": "TRP-2026-0042",
  "status": "pending",
  "programmeId": "okada_650",
  "createdAt": "2026-10-02T09:14:00Z",
  "application": {"fullName": "Adebayo Ogundele", "phoneNumber": "08023449126"},
  "official": {"verificationStatus": "unverified"},
  "events": [],
  "documents": []
}
''';

const String _messages = '''
{
  "items": [
    {
      "id": 1,
      "name": "Ibrahim Musa",
      "phone": "08059876543",
      "email": "",
      "subject": "When does the next cohort start?",
      "message": "Please I want to know the next batch date.",
      "createdAt": "2026-10-03T11:20:00Z"
    }
  ]
}
''';

const String _programmes = '''
{
  "programmes": [
    {
      "id": "okada_650",
      "label": "OKADA OWNERSHIP",
      "depositNgn": 650000,
      "months": 3,
      "asset": "1 brand-new Bajaj motorcycle",
      "summary": "N650,000 one-time deposit, 3 months."
    },
    {
      "id": "okada_400",
      "label": "OKADA OWNERSHIP",
      "depositNgn": 400000,
      "months": 6,
      "asset": "1 brand-new Bajaj motorcycle",
      "summary": "N400,000 one-time deposit, 6 months."
    },
    {
      "id": "maruwa_2300",
      "label": "MARUWA OWNERSHIP",
      "depositNgn": 2300000,
      "months": 3,
      "asset": "1 Bajaj or approved Maruwa tricycle",
      "summary": "N2,300,000 one-time deposit, 3 months."
    }
  ],
  "depositNote": "The deposit is one-time; there is no further vehicle payment."
}
''';

const String _staff = '''
{
  "items": [
    {
      "id": 1,
      "username": "admin",
      "fullName": "Portal Admin",
      "role": "admin",
      "createdAt": "2026-09-01T08:00:00Z"
    },
    {
      "id": 2,
      "username": "temi",
      "fullName": "Temi Ayo",
      "role": "reviewer",
      "createdAt": "2026-10-05T12:30:00Z"
    }
  ]
}
''';
