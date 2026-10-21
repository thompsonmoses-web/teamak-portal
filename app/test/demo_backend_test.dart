import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';

/// Exercises the in-browser demo backend that the GitHub Pages preview
/// ships with: it must answer every URL the app calls, keep its data across
/// "reloads", and refuse the same things the real API refuses.
///
/// The client is constructed with a MockClient that fails on contact, so a
/// regression that slips past the demo routing cannot silently hit the
/// network.
void main() {
  ApiClient api() => ApiClient(
        client: MockClient((request) async => throw StateError(
            'demo mode must never touch the network (${request.method} '
            '${request.url})')),
        baseUrl: demoApiBase,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Map<String, Object?> submission({String phone = '08099998888'}) =>
      <String, Object?>{
        'programmeId': 'okada_650',
        'fullName': 'Preview Rider',
        'phoneNumber': phone,
        'whatsappNumber': phone,
        'residentialAddress': '1 Test Avenue, Ibadan',
        'areaCommunity': 'Test Area',
        'nin': '12345678901',
        'parkAssociationName': 'Test Park Association',
        'hasPassportPhotograph': true,
        'hasTwoPassportPhotographs': false,
        'hasGovernmentIdOrNinSlip': true,
        'hasRiderOrAssociationRegistration': true,
        'hasProofOfResidentialAddress': true,
      };

  test('serves the programme tiers without the network', () async {
    final programmes = await api().fetchProgrammes();
    expect(programmes, hasLength(3));
    expect(programmes.first.id, 'okada_650');
    expect(programmes.last.id, 'maruwa_2300');
  });

  test('an application can be submitted and tracked back', () async {
    final client = api();
    final created = await client.submitApplication(submission());
    expect(created.applicationNo, 'TRP-2026-0005');
    expect(created.status, 'submitted');

    final tracked = await client.trackApplication(
      applicationNo: created.applicationNo,
      phone: '08099998888',
    );
    expect(tracked.application['fullName'], 'Preview Rider');
  });

  test('tracking with the wrong phone is the guarded 404', () async {
    final client = api();
    final created = await client.submitApplication(submission());
    try {
      await client.trackApplication(
        applicationNo: created.applicationNo,
        phone: '08000000000',
      );
      fail('a wrong phone must not reach the record');
    } on ApiException catch (error) {
      expect(error.statusCode, 404);
    }
  });

  test('submissions survive a fresh client — the store is persistent',
      () async {
    final first = api();
    final created = await first.submitApplication(submission());
    await first.trackApplication(
      applicationNo: created.applicationNo,
      phone: '08099998888',
    );

    // A new client stands in for a page reload: local storage is the store.
    final reloaded = await api().trackApplication(
      applicationNo: created.applicationNo,
      phone: '08099998888',
    );
    expect(reloaded.applicationNo, created.applicationNo);
  });

  group('staff area', () {
    test('signs in as the seeded demo administrator', () async {
      final session =
          await api().login(username: 'demo', password: 'demo1234');
      expect(session.username, 'demo');
      expect(session.role, 'admin');
    });

    test('lists seeded applications with counts', () async {
      final client = api();
      await client.login(username: 'demo', password: 'demo1234');
      final result = await client.listApplications();
      expect(result.total, 4);
      expect(result.counts['approved'], 1);
      expect(result.results.first.applicationNo, 'TRP-2026-0004',
          reason: 'newest first, mirroring the real listing');
    });

    test('a review decision reaches the public track view but remarks do not',
        () async {
      final client = api();
      await client.login(username: 'demo', password: 'demo1234');
      await client.updateStatus(
        id: '1',
        status: 'approved',
        remark: 'Verified at the park.',
        expectedDeliveryDate: '2027-01-15',
        approvedAmount: 650000,
      );

      final public = await client.trackApplication(
        applicationNo: 'TRP-2026-0001',
        phone: '08023449126',
      );
      expect(public.status, 'approved');
      expect(public.official['expectedDeliveryDate'], '2027-01-15');
      expect(public.official.containsKey('remarks'), isFalse,
          reason: 'staff notes stay staff-only, as on the real /track');
      expect(public.official.containsKey('receivedBy'), isFalse);
    });

    test('an unknown token is refused like a dead session', () async {
      final client = api();
      client.token = 'not-a-real-token';
      try {
        await client.listApplications();
        fail('a dead token must not reach the listing');
      } on ApiException catch (error) {
        expect(error.statusCode, 401);
      }
    });
  });

  group('team management', () {
    test('an administrator manages accounts; a reviewer is refused', () async {
      final client = api();
      await client.login(username: 'demo', password: 'demo1234');
      final accounts = await client.listStaff();
      expect(accounts, hasLength(3));
      expect(accounts.every((account) => !account.containsKey('password')),
          isTrue);

      await client.createStaff(
        username: 'newstaff',
        fullName: 'New Staff',
        password: 'secret123',
        role: 'reviewer',
      );
      final after = await client.listStaff();
      expect(after, hasLength(4));

      final reviewer = await client.login(
        username: 'newstaff',
        password: 'secret123',
      );
      expect(reviewer.role, 'reviewer');
      try {
        await client.listStaff();
        fail('a reviewer must not see the directory');
      } on ApiException catch (error) {
        expect(error.statusCode, 403);
      }
    });

    test('the last administrator cannot be demoted', () async {
      final client = api();
      await client.login(username: 'demo', password: 'demo1234');
      try {
        // id 1 is the seeded `admin`, one of the two seeded administrators —
        // demote both and the guard must stop the second one.
        await client.updateStaff(1, role: 'reviewer');
        await client.updateStaff(2, role: 'reviewer');
        fail('the final administrator must be protected');
      } on ApiException catch (error) {
        expect(error.statusCode, 400);
      }
    });
  });

  test('contact messages reach the staff inbox', () async {
    final client = api();
    final thanks = await client.submitContact(
      name: 'Preview Visitor',
      phone: '08012345678',
      email: '',
      subject: 'General enquiry',
      message: 'Is the programme still open?',
    );
    expect(thanks, contains('Thank you'));

    await client.login(username: 'demo', password: 'demo1234');
    final messages = await client.fetchMessages();
    expect(messages, hasLength(3));
    expect(messages.first.name, 'Preview Visitor');
  });
}
