import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:test/test.dart';

import '../fixtures.dart';
import '../../routes/applications/index.dart' as applications_route;
import '../../routes/applications/[id]/documents.dart' as documents_route;
import '../../routes/applications/[id]/index.dart' as detail_route;
import '../../routes/applications/[id]/status.dart' as status_route;

class _MockRequestContext extends Mock implements RequestContext {}

RequestContext _context({
  required TeamakDatabase db,
  required Request request,
}) {
  final context = _MockRequestContext();
  when(() => context.read<TeamakDatabase>()).thenReturn(db);
  when(() => context.request).thenReturn(request);
  return context;
}

Request _jsonRequest(
  String method,
  Uri uri, {
  Object? body,
  Map<String, Object>? headers,
}) =>
    Request(
      method,
      uri,
      body: body == null ? null : jsonEncode(body),
      headers: <String, Object>{
        'content-type': 'application/json',
        ...?headers,
      },
    );

Map<String, Object> _bearer(String token) =>
    <String, Object>{'authorization': 'Bearer $token'};

String _loginToken(TeamakDatabase db) {
  final token = createSessionToken();
  db.createSession(
    token: token,
    staffId: db.staffByUsername('admin')!['id'] as int,
    ttl: const Duration(hours: 1),
  );
  return token;
}

void main() {
  late TeamakDatabase db;
  final uri = Uri.parse('http://localhost/applications');

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  group('POST /applications', () {
    test('creates an application with an application number', () async {
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('POST', uri, body: validApplication()),
        ),
      );

      expect(response.statusCode, HttpStatus.created);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['applicationNo'], 'TRP-2026-0001');
      expect(body['status'], 'submitted');
      expect(db.countApplications(), 1);
    });

    test('rejects an invalid application with field errors', () async {
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'POST',
            uri,
            body: validApplication(
              overrides: <String, dynamic>{'nin': '12', 'phoneNumber': ''},
            ),
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      final errors = body['errors'] as Map<String, dynamic>;
      expect(errors.keys, containsAll(<String>['nin', 'phoneNumber']));
      expect(db.countApplications(), 0);
    });

    test('rejects a malformed JSON body', () async {
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('POST', uri, body: <String, Object?>{
            'unexpected': true,
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(db.countApplications(), 0);
    });

    test('rejects other methods', () async {
      final response = await applications_route.onRequest(
        _context(db: db, request: _jsonRequest('DELETE', uri)),
      );
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });

  group('GET /applications', () {
    setUp(() {
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
    });

    test('requires authentication', () async {
      final response = await applications_route.onRequest(
        _context(db: db, request: Request.get(uri)),
      );
      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('returns matching applications for a staff member', () async {
      final token = _loginToken(db);
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            uri.replace(queryParameters: <String, String>{'q': 'Ismaila'}),
            headers: _bearer(token),
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['total'], 1);
      expect(body['results'], hasLength(1));
      expect((body['results'] as List).first['fullName'], 'Ismaila Kamdeen');
      expect(body['counts'], isA<Map<String, dynamic>>());
    });

    test('filters by status', () async {
      final token = _loginToken(db);
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            uri.replace(queryParameters: <String, String>{
              'status': 'approved',
            }),
            headers: _bearer(token),
          ),
        ),
      );

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['total'], 0);
      expect(body['results'], isEmpty);
    });

    test('rejects an unknown status filter', () async {
      final token = _loginToken(db);
      final response = await applications_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            uri.replace(queryParameters: <String, String>{
              'status': 'bogus',
            }),
            headers: _bearer(token),
          ),
        ),
      );
      expect(response.statusCode, HttpStatus.badRequest);
    });
  });

  group('GET /applications/:id', () {
    test('returns the full application and events for staff', () async {
      final created = db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      );
      final id = '${created['id']}';
      final token = _loginToken(db);

      final response = await detail_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            Uri.parse('http://localhost/applications/$id'),
            headers: _bearer(token),
          ),
        ),
        id,
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['applicationNo'], 'TRP-2026-0001');
      expect(body['events'], isEmpty);
      final application = body['application'] as Map<String, dynamic>;
      expect(application['programmeId'], 'okada_650');
      expect(application['nextOfKin'], isA<Map<String, dynamic>>());
    });

    test('requires authentication', () async {
      final created = db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      );
      final id = '${created['id']}';
      final response = await detail_route.onRequest(
        _context(
          db: db,
          request: Request.get(Uri.parse('http://localhost/applications/$id')),
        ),
        id,
      );
      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('404s for an unknown application', () async {
      final token = _loginToken(db);
      final response = await detail_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            Uri.parse('http://localhost/applications/missing'),
            headers: _bearer(token),
          ),
        ),
        'missing',
      );
      expect(response.statusCode, HttpStatus.notFound);
    });
  });

  group('PATCH /applications/:id/status', () {
    late String id;

    setUp(() {
      id = '${db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      )['id']}';
    });

    test('approves an application and stores Section I fields', () async {
      final token = _loginToken(db);
      final response = await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/$id/status'),
            headers: _bearer(token),
            body: <String, Object?>{
              'status': 'approved',
              'remark': 'Verified',
              'approvedProgrammeId': 'okada_650',
              'approvedAmount': 650000,
              'expectedDeliveryDate': '2026-11-15',
            },
          ),
        ),
        id,
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['status'], 'approved');
      expect(body['events'], hasLength(1));
      final official = body['official'] as Map<String, dynamic>;
      expect(official['approvedAmount'], 650000);
      expect(official['expectedDeliveryDate'], '2026-11-15');
    });

    test('requires authentication', () async {
      final response = await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/$id/status'),
            body: <String, Object?>{'status': 'approved'},
          ),
        ),
        id,
      );
      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('rejects an unknown status', () async {
      final token = _loginToken(db);
      final response = await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/$id/status'),
            headers: _bearer(token),
            body: <String, Object?>{'status': 'bogus'},
          ),
        ),
        id,
      );
      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('rejects an unknown approved programme', () async {
      final token = _loginToken(db);
      final response = await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/$id/status'),
            headers: _bearer(token),
            body: <String, Object?>{
              'status': 'approved',
              'approvedProgrammeId': 'nope',
            },
          ),
        ),
        id,
      );
      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('404s for an unknown application', () async {
      final token = _loginToken(db);
      final response = await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/missing/status'),
            headers: _bearer(token),
            body: <String, Object?>{'status': 'pending'},
          ),
        ),
        'missing',
      );
      expect(response.statusCode, HttpStatus.notFound);
    });
  });

  group('documents', () {
    late String id;

    setUp(() {
      id = '${db.insertApplication(
        payload: validApplication(),
        programmeId: 'okada_650',
      )['id']}';
    });

    test('stores an uploaded document for staff', () async {
      final token = _loginToken(db);
      final uploads = await Directory.systemTemp.createTemp('teamak_uploads');
      addTearDown(() async {
        documents_route.uploadDirectoryOverride = null;
        await uploads.delete(recursive: true);
      });
      documents_route.uploadDirectoryOverride = uploads;

      final response = await documents_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'POST',
            Uri.parse('http://localhost/applications/$id/documents'),
            headers: _bearer(token),
            body: <String, Object?>{
              'kind': 'passport_photograph',
              'fileName': 'photo.png',
              'content': base64Encode(<int>[1, 2, 3, 4]),
            },
          ),
        ),
        id,
      );

      expect(response.statusCode, HttpStatus.created);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['kind'], 'passport_photograph');
      expect(body['sizeBytes'], 4);
      expect(db.documentsFor(id), hasLength(1));
    });

    test('rejects an unknown document kind', () async {
      final token = _loginToken(db);
      final response = await documents_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'POST',
            Uri.parse('http://localhost/applications/$id/documents'),
            headers: _bearer(token),
            body: <String, Object?>{
              'kind': 'passport',
              'fileName': 'photo.png',
              'content': base64Encode(<int>[1]),
            },
          ),
        ),
        id,
      );
      expect(response.statusCode, HttpStatus.badRequest);
    });
  });
}
