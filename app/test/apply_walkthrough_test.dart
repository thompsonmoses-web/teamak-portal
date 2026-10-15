import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/models/models.dart';
import 'package:teamak_app/pages/apply_page.dart';

/// The wizard is walk-through: a visitor must be able to press Continue on
/// every step without typing anything and still submit successfully. This
/// guards that promise — the demo-fill in ApplyPage is what keeps the API's
/// validator happy when every field is empty.
class _RecordingApi extends ApiClient {
  Map<String, dynamic>? submitted;

  @override
  Future<List<Programme>> fetchProgrammes() async => const <Programme>[];

  @override
  Future<ApplicationDetail> submitApplication(
    Map<String, dynamic> payload,
  ) async {
    submitted = payload;
    return const ApplicationDetail(
      id: '1',
      applicationNo: 'TGS-DEMO-1',
      status: 'submitted',
      programmeId: 'okada_400',
      createdAt: '2026-01-01T00:00:00Z',
      application: <String, dynamic>{},
      official: <String, dynamic>{},
      events: <dynamic>[],
      documents: <dynamic>[],
    );
  }
}

/// Mirrors the keys `validateApplication` in `server/lib/validation.dart`
/// insists on.
const _apiRequiredKeys = <String>[
  'fullName',
  'phoneNumber',
  'residentialAddress',
  'areaCommunity',
  'dateOfBirth',
  'nin',
  'maritalStatus',
  'operationType',
  'ridingExperience',
  'currentVehicleOwnership',
  'parkRouteOperatingArea',
  'parkAssociationName',
  'currentRemittance',
  'averageWorkingDaysPerWeek',
  'programmeId',
  'amountToCommit',
  'sourceOfFunds',
  'expectedDepositDate',
  'participatedBefore',
  'hasPassportPhotograph',
  'hasGovernmentIdOrNinSlip',
  'hasRiderOrAssociationRegistration',
  'hasProofOfResidentialAddress',
  'hasTwoPassportPhotographs',
  'nextOfKin',
  'references',
  'declarationAccepted',
  'signatureName',
  'declarationDate',
];

void main() {
  testWidgets('an empty application can still be walked through and submitted',
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
          path: '/receipt',
          builder: (context, state) => const Text('RECEIPT'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    // Six Continue presses with nothing entered — no field may block.
    for (var step = 1; step <= 6; step++) {
      final button = find.text('Continue');
      expect(button, findsOneWidget, reason: 'no Continue on step $step');
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('STEP 7 OF 7'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.submitted, isNotNull, reason: 'the wizard never submitted');
    expect(find.text('RECEIPT'), findsOneWidget);

    final payload = api.submitted!;
    for (final key in _apiRequiredKeys) {
      expect(
        payload[key],
        isNotNull,
        reason: 'the demo fill leaves "$key" null, which the API rejects',
      );
    }

    // The placeholders must satisfy the API's shape rules, not just be set.
    final nin = '${payload['nin']}';
    expect(RegExp(r'^\d{11}$').hasMatch(nin), isTrue, reason: 'NIN shape');
    final phone = '${payload['phoneNumber']}';
    expect(RegExp(r'^0[789]\d{9}$').hasMatch(phone), isTrue, reason: 'phone');
    expect(payload['references'], hasLength(2));
    expect(payload['declarationAccepted'], isTrue);
  });
}
