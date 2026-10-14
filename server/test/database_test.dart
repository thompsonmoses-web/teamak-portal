import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:server/programmes.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  late TeamakDatabase db;

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  group('application numbering', () {
    test('formats the application number', () {
      expect(
        TeamakDatabase.formatApplicationNumber(1, year: 2026),
        'TRP-2026-0001',
      );
      expect(
        TeamakDatabase.formatApplicationNumber(42, year: 2026),
        'TRP-2026-0042',
      );
    });

    test('reserves sequential numbers', () {
      final first = db.nextApplicationSequence();
      final second = db.nextApplicationSequence();
      final third = db.nextApplicationSequence();

      expect(first, 1);
      expect(second, 2);
      expect(third, 3);
    });
  });

  group('insertApplication', () {
    test('stores sections A-H and assigns a number', () {
      final payload = validApplication();
      final application = db.insertApplication(
        payload: payload,
        programmeId: 'okada_650',
      );

      expect(application['applicationNo'], 'TRP-2026-0001');
      expect(application['status'], ApplicationStatus.submitted);
      expect(application['programmeId'], 'okada_650');

      final stored = application['application'] as Map<String, dynamic>;
      expect(stored['fullName'], payload['fullName']);
      expect(stored['nin'], payload['nin']);
      expect(stored['references'], hasLength(2));

      final official = application['official'] as Map<String, Object?>;
      expect(official['verificationStatus'], ApplicationStatus.pending);
    });

    test('increments the sequence for each application', () {
      final first = db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      );
      final second = db.insertApplication(
        payload: validApplication(),
        programmeId: 'maruwa_2300',
      );

      expect(first['applicationNo'], 'TRP-2026-0001');
      expect(second['applicationNo'], 'TRP-2026-0002');
    });

    test('lists, searches and filters', () {
      db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      );
      db.insertApplication(
        payload: validApplication(
          overrides: <String, dynamic>{'fullName': 'Ismaila Kamdeen'},
        ),
        programmeId: 'okada_400',
      );

      expect(db.listApplications(), hasLength(2));
      expect(db.listApplications(query: 'Ismaila'), hasLength(1));
      expect(db.listApplications(query: 'TRP-2026-0001'), hasLength(1));
      expect(
        () => db.listApplications(status: 'unknown'),
        throwsA(isA<DatabaseException>()),
      );
      expect(db.countApplications(), 2);
      expect(db.countApplications(query: 'Ismaila'), 1);
    });
  });

  group('status flow', () {
    late String applicationId;

    setUp(() {
      applicationId = '${db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      )['id']}';
    });

    test('moves from submitted to approved with Section I data', () {
      final updated = db.updateApplicationStatus(
        id: applicationId,
        status: ApplicationStatus.approved,
        staffUsername: 'admin',
        remark: 'Verified at Ojoo park',
        receivedBy: 'Admin',
        verificationDate: '2026-10-10',
        approvedProgrammeId: 'okada_650',
        approvedAmount: 650000,
        expectedDeliveryDate: '2026-11-15',
      );

      expect(updated, isNotNull);
      expect(updated!['status'], ApplicationStatus.approved);

      final official = updated['official'] as Map<String, Object?>;
      expect(official['verificationStatus'], ApplicationStatus.approved);
      expect(official['approvedAmount'], 650000);
      expect(official['approvedProgrammeId'], 'okada_650');
      expect(official['expectedDeliveryDate'], '2026-11-15');
      expect(official['remarks'], 'Verified at Ojoo park');
      expect(official['updatedBy'], 'admin');
    });

    test('records an audit event for every change', () {
      db.updateApplicationStatus(
        id: applicationId,
        status: ApplicationStatus.pending,
        staffUsername: 'admin',
      );
      db.updateApplicationStatus(
        id: applicationId,
        status: ApplicationStatus.furtherReview,
        staffUsername: 'reviewer',
        remark: 'Awaiting park confirmation',
      );

      final events = db.applicationEvents(applicationId);
      expect(events, hasLength(2));
      expect(events.first['fromStatus'], ApplicationStatus.submitted);
      expect(events.first['toStatus'], ApplicationStatus.pending);
      expect(events.last['toStatus'], ApplicationStatus.furtherReview);
      expect(events.last['remark'], 'Awaiting park confirmation');
      expect(events.last['staffUsername'], 'reviewer');
    });

    test('rejects unknown statuses', () {
      expect(
        () => db.updateApplicationStatus(
          id: applicationId,
          status: 'bogus',
          staffUsername: 'admin',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('rejects unknown programmes', () {
      expect(
        () => db.updateApplicationStatus(
          id: applicationId,
          status: ApplicationStatus.approved,
          approvedProgrammeId: 'nope',
          staffUsername: 'admin',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('returns null for a missing application', () {
      expect(
        db.updateApplicationStatus(
          id: 'missing',
          status: ApplicationStatus.pending,
          staffUsername: 'admin',
        ),
        isNull,
      );
    });

    test('tracks status counts', () {
      db.updateApplicationStatus(
        id: applicationId,
        status: ApplicationStatus.approved,
        staffUsername: 'admin',
      );

      final counts = db.staffCounts()!;
      expect(counts['approved'], 1);
      expect(counts['submitted'], 0);
      expect(counts['total'], 1);
    });
  });

  group('staff & sessions', () {
    test('seeds an admin user', () {
      final admin = db.staffByUsername('admin');
      expect(admin, isNotNull);
      expect(admin!['role'], 'admin');
      expect(admin['passwordHash'], isNot('admin123'));
      expect(verifyPassword('admin123', admin['passwordHash'] as String), isTrue);
    });

    test('creates and resolves a session token', () {
      final admin = db.staffByUsername('admin')!;
      final token = createSessionToken();
      db.createSession(
        token: token,
        staffId: admin['id'] as int,
        ttl: const Duration(hours: 1),
      );

      final staff = db.staffForToken(token);
      expect(staff, isNotNull);
      expect(staff!['username'], 'admin');
    });

    test('rejects expired sessions', () {
      final admin = db.staffByUsername('admin')!;
      final token = createSessionToken();
      db.createSession(
        token: token,
        staffId: admin['id'] as int,
        ttl: const Duration(milliseconds: -1),
      );

      expect(db.staffForToken(token), isNull);
    });

    test('rejects unknown tokens', () {
      expect(db.staffForToken('nope'), isNull);
    });

    test('deletes a session on logout', () {
      final admin = db.staffByUsername('admin')!;
      final token = createSessionToken();
      db.createSession(
        token: token,
        staffId: admin['id'] as int,
        ttl: const Duration(hours: 1),
      );

      db.deleteSession(token);
      expect(db.staffForToken(token), isNull);
    });
  });
}
