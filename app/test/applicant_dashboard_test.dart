import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/app.dart';

/// What `POST /track` answers for the fixture pair below, in the trimmed
/// shape the endpoint returns: the applicant's own answers plus public
/// outcomes — no staff notes, no staff usernames.
const String _tracked = '''
{
  "id": "app-1",
  "applicationNo": "TRP-2026-0042",
  "status": "pending",
  "programmeId": "okada_650",
  "createdAt": "2026-10-02T09:14:00Z",
  "application": {
    "fullName": "Adebayo Ogundele",
    "phoneNumber": "08023449126",
    "areaCommunity": "Ojoo",
    "nin": "12345678901",
    "parkAssociationName": "Ojoo Okada Park",
    "hasPassportPhotograph": true,
    "hasTwoPassportPhotographs": false,
    "hasGovernmentIdOrNinSlip": true,
    "hasRiderOrAssociationRegistration": true,
    "hasProofOfResidentialAddress": false
  },
  "official": {"expectedDeliveryDate": "2026-12-01"},
  "events": [
    {
      "fromStatus": "submitted",
      "toStatus": "pending",
      "createdAt": "2026-10-02T10:00:00Z"
    }
  ],
  "documents": []
}
''';

const String _number = 'TRP-2026-0042';
const String _phone = '08023449126';

/// Stands in for the tracking endpoint: the fixture pair answers with the
/// record, everything else gets the API's 404.
ApiClient _api() => ApiClient(
      client: MockClient((request) async {
        const jsonHeaders = <String, String>{'content-type': 'application/json'};
        if (request.url.path != '/track') {
          return http.Response('{"error":"Not found."}', 404,
              headers: jsonHeaders);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final ok = body['applicationNo'] == _number &&
            body['phone'] == _phone;
        if (!ok) {
          return http.Response(
            '{"error":"No application matches that number and phone number."}',
            404,
            headers: jsonHeaders,
          );
        }
        return http.Response(_tracked, 200, headers: jsonHeaders);
      }),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpDashboard(WidgetTester tester, {String? storedRef}) async {
    // The dashboard is one long scroll, so mount it on a viewport tall
    // enough to hold it: off-screen children of a ListView are not built,
    // and finders would silently miss the summary below the header.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    if (storedRef != null) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'teamak_applicant_ref': storedRef,
      });
    }
    await tester.pumpWidget(TeamakApp(initialPath: '/dashboard', api: _api()));
    await tester.pumpAndSettle();
  }

  testWidgets('a cold visit offers the tracking form', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Find your application'), findsOneWidget);
    expect(find.text('Track application'), findsOneWidget);
    expect(find.text('Application number'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
  });

  testWidgets('a stored reference returns straight to the dashboard',
      (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    expect(
      find.text(_number),
      findsWidgets,
      reason: 'the application number should headline the dashboard',
    );
    expect(find.text('Welcome back, Adebayo'), findsOneWidget);
    expect(
      find.text('Under review'),
      findsWidgets,
      reason: 'the status shows in the header chip, the stat tile and more',
    );
    expect(find.text('Next milestone'), findsOneWidget);
    expect(
      find.text('01/12/2026'),
      findsWidgets,
      reason: 'the delivery date should surface as the next milestone',
    );
    expect(find.text('Okada ownership'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('FAQ & help'), findsOneWidget);
    expect(find.text('Adebayo Ogundele'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Your application'), findsOneWidget);
    expect(
      find.text('Expected delivery'),
      findsOneWidget,
      reason: 'public outcomes from Section I should surface',
    );
    expect(
      find.text('Getting ready for verification'),
      findsOneWidget,
      reason: 'Section E answers should read back as visit preparation',
    );
    expect(
      find.text('Proof of residential address'),
      findsOneWidget,
      reason: 'an unanswered-at-wizard item should be listed for the visit',
    );
    expect(
      find.text('Chat on WhatsApp'),
      findsOneWidget,
      reason: 'the WhatsApp channel should lead the dashboard actions',
    );
  });

  testWidgets('typing the pair reaches the same dashboard', (tester) async {
    await pumpDashboard(tester);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), _number);
    await tester.enterText(fields.at(1), _phone);
    await tester.tap(find.widgetWithText(FilledButton, 'Track application'));
    await tester.pumpAndSettle();

    expect(find.text('Find your application'), findsNothing);
    expect(find.text(_number), findsWidgets);
    expect(find.text('Under review'), findsWidgets);
  });

  testWidgets('a wrong pair stays on the form and says why', (tester) async {
    await pumpDashboard(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), _number);
    await tester.enterText(fields.at(1), '08000000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Track application'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No application matches that number and phone number.',
      ),
      findsOneWidget,
    );
    expect(find.text('Find your application'), findsOneWidget);
  });

  testWidgets('a phone that fails validation never reaches the API',
      (tester) async {
    await pumpDashboard(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), _number);
    await tester.enterText(fields.at(1), 'not-a-phone');
    await tester.tap(find.widgetWithText(FilledButton, 'Track application'));
    await tester.pump();

    expect(
      find.text('Enter a valid Nigerian number (e.g. 08023449126).'),
      findsOneWidget,
    );
    expect(find.text('Find your application'), findsOneWidget);
  });
}
