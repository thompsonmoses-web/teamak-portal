import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/app.dart';
import 'package:teamak_app/models/models.dart';
import 'package:teamak_app/pages/applicant_dashboard_page.dart';

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
    "dateOfBirth": "1990-05-14",
    "operationType": "okada",
    "ridingExperience": "y4_6",
    "vehicleMakeModel": "Bajaj Boxer 150",
    "parkRouteOperatingArea": "Ojoo - UI Gate",
    "averageWorkingDaysPerWeek": 6,
    "amountToCommit": "650000",
    "sourceOfFunds": ["personal_savings", "business_income"],
    "expectedDepositDate": "2026-11-01",
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
ApiClient _api({String? fixture}) => ApiClient(
  client: MockClient((request) async {
    const jsonHeaders = <String, String>{'content-type': 'application/json'};
    if (request.url.path != '/track') {
      return http.Response('{"error":"Not found."}', 404, headers: jsonHeaders);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final ok = body['applicationNo'] == _number && body['phone'] == _phone;
    if (!ok) {
      return http.Response(
        '{"error":"No application matches that number and phone number."}',
        404,
        headers: jsonHeaders,
      );
    }
    return http.Response(fixture ?? _tracked, 200, headers: jsonHeaders);
  }),
);

/// The same record moved to approved, carrying the Section I answers
/// staff record at that point — derived so it cannot drift from the base.
String get _approved => _tracked
    .replaceFirst('"status": "pending"', '"status": "approved"')
    .replaceFirst(
      '"official": {"expectedDeliveryDate": "2026-12-01"}',
      '"official": {"verificationDate": "2026-10-20", '
          '"approvedAmount": "700000", "expectedDeliveryDate": "2030-06-15"}',
    );

/// Approved before staff record any outcome: the card must wait with
/// the rider instead of inventing a date or a figure.
String get _approvedBare => _tracked
    .replaceFirst('"status": "pending"', '"status": "approved"')
    .replaceFirst(
      '"official": {"expectedDeliveryDate": "2026-12-01"}',
      '"official": {}',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpDashboard(
    WidgetTester tester, {
    String? storedRef,
    String? pin,
    String? fixture,
    String initialPath = '/dashboard',
    Size size = const Size(800, 4800),
  }) async {
    // The dashboard is one long scroll, so mount it on a viewport tall
    // enough to hold it: a tap has to hit-test its target, and the
    // tracking form's list still builds its children lazily. Height
    // grows with every card — keep it clear of the current total.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = <String, Object>{};
    if (storedRef != null) saved['teamak_applicant_ref'] = storedRef;
    if (pin != null) saved['teamak_dashboard_pin'] = pin;
    SharedPreferences.setMockInitialValues(saved);
    await tester.pumpWidget(
      TeamakApp(
        initialPath: initialPath,
        api: _api(fixture: fixture),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a cold visit offers the tracking form', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Find your application'), findsOneWidget);
    expect(find.text('Track application'), findsOneWidget);
    expect(find.text('Application number'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
  });

  testWidgets('a stored reference returns straight to the dashboard', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    expect(
      find.text(_number),
      findsWidgets,
      reason: 'the application number should headline the dashboard',
    );
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(
      find.text('Under review'),
      findsWidgets,
      reason: 'the status leads the KPI card, the banner and the record rows',
    );
    expect(find.text('NEXT MILESTONE'), findsOneWidget);
    expect(
      find.text('01/12/2026'),
      findsWidgets,
      reason: 'the delivery date should surface as the next milestone',
    );
    expect(
      find.text('Okada ownership'),
      findsWidgets,
      reason: 'the plan name shows in the plan card',
    );
    expect(find.text('Application journey'), findsOneWidget);
    expect(
      find.text('Step 2 of 4'),
      findsOneWidget,
      reason: 'a pending application sits on the second of four steps',
    );
    expect(
      find.text('Checks underway — keep your phone reachable.'),
      findsOneWidget,
    );
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('₦650,000 deposit'), findsOneWidget);
    expect(find.text('Your commitment'), findsOneWidget);
    expect(
      find.text('₦650,000'),
      findsOneWidget,
      reason: 'the funding step answers should read back as the commitment',
    );
    expect(
      find.text('One deposit only — no further payment for the vehicle.'),
      findsOneWidget,
      reason: 'the honesty line: one deposit, nothing further for the vehicle',
    );
    expect(find.text('Expected deposit date'), findsOneWidget);
    expect(find.text('01/11/2026'), findsOneWidget);
    expect(find.text('Source of funds'), findsOneWidget);
    expect(
      find.text('Personal savings, Business income'),
      findsOneWidget,
      reason: 'the saved fund chips should read back as words',
    );
    expect(find.text('Riding details'), findsOneWidget);
    expect(
      find.textContaining('Checked'),
      findsOneWidget,
      reason: 'the account says when its data was last pulled',
    );
    expect(
      find.text('Okada (motorcycle)'),
      findsOneWidget,
      reason: 'Section B codes should read in the wizard\u2019s own words',
    );
    expect(find.text('4–6 years'), findsOneWidget);
    expect(find.text('Bajaj Boxer 150'), findsOneWidget);
    expect(find.text('Ojoo - UI Gate'), findsOneWidget);
    expect(find.text('14/05/1990'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Invite a rider'), findsOneWidget);
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

  testWidgets('tapping the application number copies it', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pumpAndSettle();

    expect(
      find.text('$_number copied'),
      findsOneWidget,
      reason: 'the copy should confirm with the number itself',
    );
  });

  test('due countdown reads the days in chip words', () {
    DateTime at(int y, int m, int d) => DateTime(y, m, d);

    expect(dueCountdown(at(2026, 11, 1), now: at(2026, 10, 27)), 'in 5 days');
    expect(
      dueCountdown(at(2026, 11, 1), now: at(2026, 10, 31)),
      'due tomorrow',
    );
    expect(dueCountdown(at(2026, 11, 1), now: at(2026, 11, 1)), 'due today');
    expect(
      dueCountdown(at(2026, 11, 1), now: at(2026, 11, 5)),
      isNull,
      reason: 'a passed date shows no countdown, only the date itself',
    );
  });

  test('the WhatsApp follow-up speaks to the status', () {
    expect(
      followUpText(_number, 'pending'),
      'Hello Teamak, I am following up on my application $_number '
      '(Under review).',
    );
    expect(
      followUpText(_number, 'approved'),
      contains('ready for the deposit and handover'),
    );
    expect(
      followUpText(_number, 'not_approved'),
      contains('when I may apply again'),
    );
  });

  test('the saved receipt carries the submission, never the NIN', () {
    final detail = ApplicationDetail.fromJson(
      jsonDecode(_tracked) as Map<String, dynamic>,
    );
    final receipt = receiptText(detail);

    expect(receipt, contains('Application no:'));
    expect(receipt, contains(_number));
    expect(receipt, contains('Under review'));
    expect(receipt, contains('Adebayo Ogundele'));
    expect(receipt, contains('Ojoo Okada Park'));
    expect(
      receipt,
      isNot(contains('12345678901')),
      reason: 'a shared file must not carry the NIN',
    );
  });

  testWidgets('saving the receipt works, or the page says why', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    // This test binding has no downloads (the stub throws), so the page
    // should explain rather than fail.
    await tester.tap(find.text('Save receipt'));
    await tester.pumpAndSettle();

    expect(find.textContaining('screenshot this dashboard'), findsOneWidget);
  });

  testWidgets('a tracking link opens the form with the number filled in', (
    tester,
  ) async {
    await pumpDashboard(tester, initialPath: '/dashboard?no=$_number');

    expect(find.text('Find your application'), findsOneWidget);
    expect(
      find.text(_number),
      findsWidgets,
      reason: 'the link should spare the rider retyping their number',
    );
    expect(
      find.text(_phone),
      findsNothing,
      reason: 'the phone check still happens on every device',
    );
  });

  testWidgets('a real build never reads a phone from the URL', (tester) async {
    // Tests (and any non-demo build) run without API_BASE=demo, so the
    // showcase shortcut is inert there: the number may fill in, the phone
    // never does, and no record opens itself.
    await pumpDashboard(
      tester,
      initialPath: '/dashboard?no=$_number&phone=0123456789',
    );

    expect(find.text('Find your application'), findsOneWidget);
    expect(find.text(_number), findsWidgets);
    expect(find.text('0123456789'), findsNothing);
    expect(find.textContaining('Welcome back'), findsNothing);
  });

  testWidgets('a device PIN locks the dashboard until it is entered', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      pin: '1234',
    );

    expect(find.text('Dashboard locked'), findsOneWidget);
    expect(find.textContaining('Welcome back'), findsNothing);

    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN — try again.'), findsOneWidget);
    expect(find.text('Dashboard locked'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome back'), findsOneWidget);
  });

  testWidgets('forgot PIN turns the lock off rather than blocking', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      pin: '1234',
    );

    await tester.tap(find.text('Forgot PIN? Remove it'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('PIN lock turned off for this device.'), findsOneWidget);
  });

  testWidgets('the account card copies the tracking link', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    expect(find.text('Account & security'), findsOneWidget);
    expect(find.textContaining('no=$_number'), findsOneWidget);
    expect(find.text('Remembers $_number'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.textContaining('no=$_number'));
    await tester.pumpAndSettle();
    expect(find.text('Tracking link copied'), findsOneWidget);
  });

  testWidgets('the PIN can be turned on and off from the account card', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(find.text('Set a dashboard PIN'), findsOneWidget);

    // The dialog's fields are plain TextFields (obscured, digits only).
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.enterText(find.byType(TextField).last, '1235');
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
    expect(find.text('PINs do not match.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
    expect(find.text('PIN lock saved for this device.'), findsOneWidget);
    expect(find.text('On for this device'), findsOneWidget);

    // Snackbar confirmations queue their turn: let the save message play
    // out before the next action produces its own.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(find.text('PIN lock turned off for this device.'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('the dashboard can pull a fresh copy of itself', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
    );

    expect(find.textContaining('Checked'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    // The same record comes back — the dashboard stays up, re-checked.
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.textContaining('Checked'), findsOneWidget);
  });

  testWidgets('an approved application gets the handover card', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      fixture: _approved,
    );

    expect(find.text('Your handover'), findsOneWidget);
    expect(find.text('Expected delivery'), findsOneWidget);
    expect(
      find.text('15/06/2030'),
      findsWidgets,
      reason: 'the date shows in the milestone tile and the handover row',
    );
    expect(
      find.text('Approved amount'),
      findsOneWidget,
      reason: 'the handover card holds it — the record card must not repeat it',
    );
    expect(find.text('₦700,000'), findsOneWidget);
    expect(find.text("Tell them I'm ready"), findsOneWidget);
    // The chip counts in the pure function's own words for that date.
    expect(find.text(dueCountdown(DateTime(2030, 6, 15))!), findsOneWidget);
    // What already happened stays in the record card.
    expect(find.text('Verification date'), findsOneWidget);
    expect(find.text('20/10/2026'), findsOneWidget);
  });

  testWidgets('approved with nothing recorded waits instead of inventing', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      fixture: _approvedBare,
    );

    expect(find.text('Your handover'), findsOneWidget);
    expect(
      find.text(
        'Our team will confirm your delivery date — keep your phone reachable.',
      ),
      findsOneWidget,
    );
    expect(find.text('Expected delivery'), findsNothing);
    expect(find.text('Approved amount'), findsNothing);
    expect(find.text("Tell them I'm ready"), findsOneWidget);
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
      find.text('No application matches that number and phone number.'),
      findsOneWidget,
    );
    expect(find.text('Find your application'), findsOneWidget);
  });

  testWidgets('a phone that fails validation never reaches the API', (
    tester,
  ) async {
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

  testWidgets('a desktop viewport wears the rail, the top bar and the '
      'tinted canvas', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      size: const Size(1280, 900),
    );

    // The reference's chrome: a top-bar title, sectioned rail, and the
    // way out — every entry a real section of this one page.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('MAIN'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('My plan'), findsOneWidget);
    expect(find.text('Status history'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    // The rail's short labels must not shadow the cards they jump to:
    // each card keeps its own title, exactly once.
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Account & security'), findsOneWidget);

    // The member chip carries the real name and number, and the KPI
    // row still headlines its four labels.
    expect(find.text('Adebayo Ogundele'), findsWidgets);
    expect(find.text(_number), findsWidgets);
    expect(find.text('APPLICATION STATUS'), findsOneWidget);
    expect(find.text('NEXT MILESTONE'), findsOneWidget);
  });

  testWidgets('a rail entry scrolls its section into view', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      size: const Size(1280, 900),
    );

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;
    expect(before, 0);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(
      scrollable.position.pixels,
      greaterThan(before),
      reason: 'the rail should bring the account section into view',
    );
  });

  testWidgets('the rail signs out only after a confirmation', (tester) async {
    await pumpDashboard(
      tester,
      storedRef: '{"applicationNo":"$_number","phone":"$_phone"}',
      size: const Size(1280, 900),
    );

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of this device?'), findsOneWidget);
    expect(
      find.textContaining('this device just stops remembering'),
      findsOneWidget,
    );

    // Staying changes nothing: the overview is still on screen.
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of this device?'), findsNothing);
    expect(find.text('MAIN'), findsOneWidget);
  });
}
