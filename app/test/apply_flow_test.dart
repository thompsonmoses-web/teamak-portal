import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/form/steps_sections.dart';
import 'package:teamak_app/models/models.dart';
import 'package:teamak_app/pages/apply_page.dart';

import 'support/fields.dart';

/// Captures the payload the wizard submits, so the test can check it against
/// the API's required fields without standing up a server.
class _RecordingApi extends ApiClient {
  Map<String, dynamic>? submitted;

  /// Empty so the wizard uses its own fallback list: otherwise the result
  /// depends on whether the tests' HTTP mock answers `/programmes`.
  @override
  Future<List<Programme>> fetchProgrammes() async => const <Programme>[];

  @override
  Future<ApplicationDetail> submitApplication(
    Map<String, dynamic> payload,
  ) async {
    submitted = payload;
    return const ApplicationDetail(
      id: '1',
      applicationNo: 'TGS-0001',
      status: 'submitted',
      programmeId: 'okada_650',
      createdAt: '2026-01-01T00:00:00Z',
      application: <String, dynamic>{},
      official: <String, dynamic>{},
      events: <dynamic>[],
      documents: <dynamic>[],
    );
  }
}

/// Mirrors the keys `validateApplication` in `server/lib/validation.dart`
/// insists on. Kept in step with that file so a payload the wizard produces
/// but the API rejects cannot slip through unnoticed.
const _apiRequiredKeys = <String>[
  // Section A
  'fullName',
  'phoneNumber',
  'residentialAddress',
  'areaCommunity',
  'dateOfBirth',
  'nin',
  'maritalStatus',
  // Section B
  'operationType',
  'ridingExperience',
  'currentVehicleOwnership',
  'parkRouteOperatingArea',
  'parkAssociationName',
  'currentRemittance',
  'averageWorkingDaysPerWeek',
  // Section C and D
  'programmeId',
  'amountToCommit',
  'sourceOfFunds',
  'expectedDepositDate',
  'participatedBefore',
  // Section E
  'hasPassportPhotograph',
  'hasGovernmentIdOrNinSlip',
  'hasRiderOrAssociationRegistration',
  'hasProofOfResidentialAddress',
  'hasTwoPassportPhotographs',
  // Section F and G
  'nextOfKin',
  'references',
  // Section H
  'declarationAccepted',
  'signatureName',
  'declarationDate',
];

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void main() {
  testWidgets('the wizard collects every field the API requires',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    final router = GoRouter(
      initialLocation: '/apply',
      routes: <RouteBase>[
        GoRoute(
          path: '/apply',
          builder: (context, state) => ApplyPage(api: api),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const Text('DASHBOARD'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    // Only the current step is in the tree, and several steps reuse a label
    // (a reference and the next of kin are both "Relationship"), so callers
    // disambiguate by index.
    Future<void> fill(String label, String value, {int index = 0}) async {
      final field = fieldWithLabel(label, index: index);
      expect(field, isNotNull, reason: 'no field labelled "$label"');
      final target = field!;
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.enterText(target, value);
    }

    Future<void> choose(String label, {int index = 0}) async {
      final option = find.text(label).at(index);
      expect(option, findsOneWidget, reason: 'no option "$label" #$index');
      await tester.ensureVisible(option);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(option);
      await tester.pump();
    }

    Future<void> next() async {
      final button = find.text('Continue');
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('STEP 1 OF 7'), findsOneWidget);

    // Section A.
    await fill('Full name *', 'Adebayo Ogundele');
    await fill('Phone number *', '08023449126');
    await fill('Residential address *', '12 Ojoo Road, Ibadan');
    await fill('Area / community *', 'Ojoo');
    await fill('Date of birth *', '1990-05-14');
    await fill('NIN *', '12345678901');
    await choose('Married');
    await next();

    // Section B.
    expect(find.text('STEP 2 OF 7'), findsOneWidget);
    await choose('Okada (motorcycle)');
    await choose('4–6 years');
    await choose('Owned by me');
    await fill('Park / route / operating area *', 'Ojoo - UI Gate');
    await fill('Park association name *', 'Ojoo Okada Park');
    await fill('Current daily remittance *', '1,500 Naira daily');
    await fill('Working days per week *', '6');
    await next();

    // Section C. The two OKADA cards share a label, so they are addressed by
    // index; the second tap also proves the deposit figure follows a change
    // of mind rather than keeping the first card's amount.
    expect(find.text('STEP 3 OF 7'), findsOneWidget);
    await choose('OKADA OWNERSHIP', index: 0);
    await choose('OKADA OWNERSHIP', index: 1);
    await next();

    // Section D. Today is used deliberately: the field compares whole calendar
    // days, so a deposit due today is valid and must not be rejected.
    expect(find.text('STEP 4 OF 7'), findsOneWidget);
    await choose('Personal savings');
    await fill('Expected deposit date *', _isoDate(DateTime.now()));
    await choose('No');
    await next();

    // Section E — "No" is a real answer, not an unanswered question.
    expect(find.text('STEP 5 OF 7'), findsOneWidget);
    for (var i = 0; i < DocumentsStep.keys.length; i++) {
      // Every question carries both labels, so the index picks the row.
      final option = i == 4 ? find.text('No').at(4) : find.text('Yes').at(i);
      expect(option, findsOneWidget, reason: 'document row $i');
      await tester.ensureVisible(option);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(option);
      await tester.pump();
    }
    await next();

    // Sections F and G.
    expect(find.text('STEP 6 OF 7'), findsOneWidget);
    await fill('Next of kin name *', 'Folake Ogundele');
    await fill('Next of kin phone *', '08031234567');
    await fill('Relationship *', 'Wife');
    await fill('Next of kin address *', '12 Ojoo Road, Ibadan');
    await fill('Full name *', 'Sunday Adeyemi', index: 0);
    await fill('Relationship *', 'Park Chairman', index: 1);
    await fill('Phone number *', '08055556666');
    await fill('Address *', 'Ojoo Park, Ibadan', index: 0);
    await fill('Full name *', 'Grace Balogun', index: 1);
    await fill('Relationship *', 'Neighbour', index: 2);
    await fill('Phone number *', '08077778888', index: 1);
    await fill('Address *', 'Aba Opa, Ibadan', index: 1);
    await next();

    // Section H.
    expect(find.text('STEP 7 OF 7'), findsOneWidget);
    await choose('I accept and confirm my details are true.');
    await tester.ensureVisible(find.text('Submit'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.submitted, isNotNull, reason: 'the wizard never submitted');
    expect(find.text('DASHBOARD'), findsOneWidget);

    final payload = api.submitted!;
    for (final key in _apiRequiredKeys) {
      expect(
        payload[key],
        isNotNull,
        reason: 'the wizard omits "$key", which the API requires',
      );
    }

    expect(payload['sourceOfFunds'], <String>['personal_savings']);
    expect(payload['references'], hasLength(2));
    expect(payload['hasTwoPassportPhotographs'], isFalse);
    // Changing programme must refresh this, or the first choice's figure is
    // submitted alongside the second choice (okada_650 then okada_400).
    expect(payload['amountToCommit'], '400000');
  });
}
