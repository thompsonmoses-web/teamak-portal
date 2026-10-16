import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/app.dart';

import 'support/fields.dart';

/// Collects the text painted inside [node]'s subtree.
///
/// Rendered copy is what makes an overflow report actionable: the framework
/// gives sizes but not which label overflowed.
String _textOf(RenderObject node) {
  final out = <String>[];
  void walk(RenderObject n) {
    if (n is RenderParagraph) out.add('"${n.text.toPlainText()}"');
    n.visitChildren(walk);
  }

  walk(node);
  return out.join(' + ');
}

/// Finds every horizontal RenderFlex whose children extend past its own width.
///
/// Walking the render tree beats catching the framework's overflow assertion:
/// that report names only the first offender and truncates its ancestor chain,
/// so a page with several overflows needs one pass to surface all of them.
Set<String> flexOverflows(WidgetTester tester) {
  final hits = <String>{};

  void walk(RenderObject node) {
    // Children outside the viewport are kept but not laid out; asking such a
    // box for its size throws, and it has no geometry to compare anyway.
    if (node is! RenderBox || !node.hasSize) {
      node.visitChildren(walk);
      return;
    }
    if (node is RenderFlex && node.size.width > 0) {
      var extent = 0.0;
      node.visitChildren((raw) {
        if (raw is! RenderBox || !raw.hasSize) return;
        final parentData = raw.parentData;
        if (parentData is! BoxParentData) return;
        final right = parentData.offset.dx + raw.size.width;
        if (extent < right) extent = right;
      });
      if (extent > node.size.width + 0.5) {
        hits.add(
          'overflows by ${(extent - node.size.width).toStringAsFixed(0)}px '
          '(needs ${extent.toStringAsFixed(0)} of '
          '${node.size.width.toStringAsFixed(0)}) — ${_textOf(node)}',
        );
      }
    }
    node.visitChildren(walk);
  }

  walk(tester.renderObject(find.byType(MaterialApp)));
  return hits;
}

/// Types into the first field carrying [label], if the current step has one.
Future<void> _fill(WidgetTester tester, String label, String value,
        {int index = 0}) async =>
    fillField(tester, label, value, index: index);

/// Taps the first option carrying [label] that is on screen.
Future<void> _choose(WidgetTester tester, String label, {int index = 0}) async =>
    tapOption(tester, label, index: index);

/// Answers the current wizard step so `Continue` passes validation.
///
/// Without this the walk stalls on step one: an untouched form fails
/// `validate()` and the overflow sweep would never see sections D, E or G.
Future<void> _completeStep(WidgetTester tester, int step) async {
  switch (step) {
    case 0:
      await _fill(tester, 'Full name *', 'Adebayo Ogundele');
      await _fill(tester, 'Phone number *', '08023449126');
      await _fill(tester, 'Residential address *', '12 Ojoo Road, Ibadan');
      await _fill(tester, 'Area / community *', 'Ojoo');
      await _fill(tester, 'Date of birth *', '1990-05-14');
      await _fill(tester, 'NIN *', '12345678901');
      await _choose(tester, 'Single');
    case 1:
      await _choose(tester, 'Okada (motorcycle)');
      await _choose(tester, '4–6 years');
      await _choose(tester, 'Owned by me');
      await _fill(tester, 'Park / route / operating area *', 'Ojoo - UI Gate');
      await _fill(tester, 'Park association name *', 'Ojoo Okada Park');
      await _fill(tester, 'Current daily remittance *', '1,500 Naira daily');
      await _fill(tester, 'Working days per week *', '6');
    case 2:
      await _choose(tester, 'OKADA OWNERSHIP');
    case 3:
      await _choose(tester, 'Personal savings');
      final deposit = DateTime.now().add(const Duration(days: 30));
      await _fill(
        tester,
        'Expected deposit date *',
        '${deposit.year.toString().padLeft(4, '0')}-'
        '${deposit.month.toString().padLeft(2, '0')}-'
        '${deposit.day.toString().padLeft(2, '0')}',
      );
      await _choose(tester, 'No');
    case 4:
      // Every document question must be answered to advance.
      for (var i = 0; i < 5; i++) {
        await _choose(tester, 'Yes', index: i);
      }
    case 5:
      await _fill(tester, 'Next of kin name *', 'Folake Ogundele');
      await _fill(tester, 'Next of kin phone *', '08031234567');
      await _fill(tester, 'Relationship *', 'Wife');
      await _fill(tester, 'Next of kin address *', '12 Ojoo Road, Ibadan');
      await _fill(tester, 'Full name *', 'Sunday Adeyemi', index: 0);
      await _fill(tester, 'Relationship *', 'Park Chairman', index: 1);
      await _fill(tester, 'Phone number *', '08055556666');
      await _fill(tester, 'Address *', 'Ojoo Park, Ibadan', index: 0);
      await _fill(tester, 'Full name *', 'Grace Balogun', index: 1);
      await _fill(tester, 'Relationship *', 'Neighbour', index: 2);
      await _fill(tester, 'Phone number *', '08077778888', index: 1);
      await _fill(tester, 'Address *', 'Aba Opa, Ibadan', index: 1);
  }
}

/// Fixture payload standing in for the API behind the staff area.
///
/// The signed-in pages are only reachable with data: an empty list renders a
/// placeholder, so the filter chips, status cards and answer rows the sweep
/// is meant to exercise would never be laid out.
const String _staffApplications = '''
{
  "total": 3,
  "counts": {"pending": 1, "approved": 1, "rejected": 1},
  "results": [
    {
      "id": "1",
      "applicationNo": "TG-2026-0042",
      "status": "pending",
      "fullName": "Adebayo Ogundele",
      "phoneNumber": "08023449126",
      "programmeId": "1",
      "areaCommunity": "Ojoo, Ibadan",
      "createdAt": "2026-10-02T09:14:00Z",
      "official": {"verificationStatus": "unverified"}
    },
    {
      "id": "2",
      "applicationNo": "TG-2026-0039",
      "status": "approved",
      "fullName": "Folake Adeyemi",
      "phoneNumber": "08031234567",
      "programmeId": "2",
      "areaCommunity": "Aba Opa, Ibadan",
      "createdAt": "2026-09-28T14:02:00Z",
      "official": {"verificationStatus": "verified"}
    },
    {
      "id": "3",
      "applicationNo": "TG-2026-0035",
      "status": "rejected",
      "fullName": "Sunday Balogun",
      "phoneNumber": "08055556666",
      "programmeId": "1",
      "areaCommunity": "Oluyole, Ibadan",
      "createdAt": "2026-09-21T08:45:00Z",
      "official": {"verificationStatus": "failed"}
    }
  ]
}
''';

const String _staffApplication = '''
{
  "id": "1",
  "applicationNo": "TG-2026-0042",
  "status": "pending",
  "programmeId": "1",
  "createdAt": "2026-10-02T09:14:00Z",
  "application": {
    "fullName": "Adebayo Ogundele",
    "phoneNumber": "08023449126",
    "whatsappNumber": "08023449126",
    "residentialAddress": "12 Ojoo Road, Ibadan",
    "areaCommunity": "Ojoo, Ibadan",
    "dateOfBirth": "1990-05-14",
    "nin": "12345678901",
    "maritalStatus": "Single",
    "operationType": "okada",
    "ridingExperience": "4-6 years",
    "currentVehicleOwnership": "Owned by me",
    "vehicleMakeModel": "Bajaj Boxer 150",
    "parkRouteOperatingArea": "Ojoo - UI Gate",
    "parkAssociationName": "Ojoo Okada Park",
    "currentRemittance": "1,500 Naira daily",
    "averageWorkingDaysPerWeek": "6",
    "programmeId": "1",
    "amountToCommit": "400000",
    "sourceOfFunds": "Personal savings",
    "expectedDepositDate": "2026-11-01",
    "participatedBefore": false,
    "previousProgrammeDetails": "",
    "hasPassportPhotograph": true,
    "hasGovernmentIdOrNinSlip": true,
    "hasRiderOrAssociationRegistration": false,
    "hasProofOfResidentialAddress": true,
    "hasTwoPassportPhotographs": false,
    "nextOfKin": {
      "fullName": "Folake Ogundele",
      "relationship": "Wife",
      "phoneNumber": "08031234567",
      "address": "12 Ojoo Road, Ibadan"
    },
    "references": [
      {
        "fullName": "Sunday Adeyemi",
        "relationship": "Park Chairman",
        "phoneNumber": "08055556666",
        "address": "Ojoo Park, Ibadan"
      },
      {
        "fullName": "Grace Balogun",
        "relationship": "Neighbour",
        "phoneNumber": "08077778888",
        "address": "Aba Opa, Ibadan"
      }
    ],
    "declarationAccepted": true,
    "signatureName": "Adebayo Ogundele",
    "declarationDate": "2026-10-02"
  },
  "official": {},
  "events": [
    {
      "fromStatus": "submitted",
      "toStatus": "pending",
      "remark": "Received at the Ibadan office",
      "staffUsername": "admin",
      "createdAt": "2026-10-02T10:00:00Z"
    }
  ],
  "documents": []
}
''';

const String _staffMessages = '''
{
  "messages": [
    {
      "id": 1,
      "name": "Adebayo Ogundele",
      "phone": "08023449126",
      "email": "ade@example.com",
      "subject": "Application status",
      "message": "Good day, please when does the next cohort open for Ibadan?",
      "createdAt": "2026-10-10T09:00:00Z"
    },
    {
      "id": 2,
      "name": "Grace Balogun",
      "phone": "08077778888",
      "email": "",
      "subject": "Deposit date",
      "message": "I have paid the deposit, who do I send the receipt to?",
      "createdAt": "2026-10-11T15:30:00Z"
    }
  ]
}
''';

/// A client answering every route the staff area calls.
///
/// Unknown paths return an empty object rather than an error, so an endpoint
/// added later degrades to an empty page instead of an exception mid-sweep.
ApiClient _staffApi() => ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        final String body;
        if (path == '/auth/me') {
          body = '{"username":"admin","fullName":"Portal Admin","role":"admin"}';
        } else if (path == '/applications') {
          body = _staffApplications;
        } else if (path.startsWith('/applications/')) {
          body = _staffApplication;
        } else if (path == '/contact') {
          body = _staffMessages;
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

/// Asserts a staff sweep landed on the page it meant to test.
///
/// Without this the guard is absent: a session the API refused redirects to
/// the sign-in form, which fits every width, so the sweep would report
/// success having measured the wrong page.
void _expectOnStaffPage(WidgetTester tester, String title) {
  expect(
    find.text(title),
    findsWidgets,
    reason: 'expected the signed-in page to render its own title',
  );
  expect(
    find.text('Sign in'),
    findsNothing,
    reason: 'the session was bounced to the login form, so nothing was swept',
  );
}

/// Pumps [path], walks the page so lazily built sections are laid out, and
/// fails if any horizontal RenderFlex overflows at any point.
Future<void> _checkRoute(
  WidgetTester tester,
  int width, {
  String path = '/',
  ApiClient? api,
  bool staff = false,
}) async {
  tester.view.physicalSize = Size(width.toDouble(), 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The router holds every /staff route at sign-in until a session exists,
  // and a session is restored from a stored token: seed one so the sweep
  // reaches the signed-in pages instead of the login form.
  if (staff) {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'teamak_staff_token': 'sweep-token',
    });
  }

  await tester.pumpWidget(TeamakApp(initialPath: path, api: api));
  await tester.pump(const Duration(milliseconds: 400));

  // The walk runs every frame, not just at the end: some sections overflow
  // only mid-animation (the sticky bar slides in, the promo popup fades in)
  // and are laid out correctly again once they settle.
  final overflows = <String>{};
  for (var i = 0; i < 40; i++) {
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pump(const Duration(milliseconds: 60));
    overflows.addAll(flexOverflows(tester));
  }

  expect(overflows, isEmpty, reason: '$path at ${width}px: $overflows');
}

void main() {
  // Widths span a small Android phone, the common iPhone sizes, a large phone,
  // a tablet and a desktop, so a regression on any class of screen is caught.
  const widths = <int>[320, 360, 390, 414, 480, 768, 1280];

  for (final width in widths) {
    testWidgets('landing page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width);
    });

    testWidgets('apply wizard fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/apply');

      // The wizard holds seven steps of different field shapes, so step one
      // alone would not prove the rest fit. Answer each step, advance, and
      // sweep for overflow after every transition.
      for (var step = 0; step < 7; step++) {
        expect(
          flexOverflows(tester),
          isEmpty,
          reason: 'apply step $step at ${width}px',
        );
        if (find.text('Continue').evaluate().isEmpty) break;
        await _completeStep(tester, step);
        await tester.ensureVisible(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        flexOverflows(tester),
        isEmpty,
        reason: 'apply final step at ${width}px',
      );
    });

    testWidgets('contact page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/contact');
    });

    testWidgets('about page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/about');
    });

    testWidgets('what we do page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/what-we-do');
    });

    testWidgets('team page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/team');
    });

    testWidgets('staff login fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/staff/login');
    });

    testWidgets('staff dashboard fits a ${width}px viewport', (tester) async {
      await _checkRoute(
        tester,
        width,
        path: '/staff',
        api: _staffApi(),
        staff: true,
      );
      _expectOnStaffPage(tester, 'Applications');
    });

    testWidgets('staff messages fits a ${width}px viewport', (tester) async {
      await _checkRoute(
        tester,
        width,
        path: '/staff/messages',
        api: _staffApi(),
        staff: true,
      );
      _expectOnStaffPage(tester, 'Messages');
    });

    testWidgets('application review fits a ${width}px viewport',
        (tester) async {
      await _checkRoute(
        tester,
        width,
        path: '/staff/applications/1',
        api: _staffApi(),
        staff: true,
      );
      _expectOnStaffPage(tester, 'Application review');
    });

    testWidgets('404 page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/no-such-page');
    });
  }
}
