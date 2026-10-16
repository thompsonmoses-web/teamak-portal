import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:test/test.dart';

import '../fixtures.dart';
import '../../routes/applications/index.dart' as applications_route;
import '../../routes/applications/[id]/status.dart' as status_route;
import '../../routes/track/index.dart' as track_route;

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
  final trackUri = Uri.parse('http://localhost/track');
  final applicationsUri = Uri.parse('http://localhost/applications');

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  /// Files the fixture application and returns its receipt payload.
  Future<Map<String, dynamic>> file() async {
    final response = await applications_route.onRequest(
      _context(
        db: db,
        request: _jsonRequest('POST', applicationsUri, body: validApplication()),
      ),
    );
    // The submit endpoint answers 201 Created, the receipt payload inside.
    expect(response.statusCode, HttpStatus.created);
    return jsonDecode(await response.body()) as Map<String, dynamic>;
  }

  /// Posts to `/track` and returns the status, raw body and decoded body.
  Future<({int status, String raw, Map<String, dynamic> body})> track(
    Map<String, Object?> body,
  ) async {
    final response = await track_route.onRequest(
      _context(db: db, request: _jsonRequest('POST', trackUri, body: body)),
    );
    final raw = await response.body();
    return (
      status: response.statusCode,
      raw: raw,
      body: jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  group('POST /track', () {
    test('returns the application when number and phone match', () async {
      final created = await file();
      final result = await track(<String, Object?>{
        'applicationNo': created['applicationNo'],
        'phone': '08023449126',
      });

      expect(result.status, HttpStatus.ok);
      expect(result.body['applicationNo'], created['applicationNo']);
      expect(result.body['status'], 'submitted');
      expect(
        (result.body['application'] as Map)['fullName'],
        'Adebayo Ogundele',
        reason: 'the owner reads their own answers back as the receipt did',
      );
      expect(result.body['events'], isA<List<Object?>>());
    });

    test('accepts phone numbers written the other common ways', () async {
      final created = await file();
      for (final phone in <String>[
        '+234 802 344 9126',
        '2348023449126',
        '080 2344 9126',
      ]) {
        final result = await track(<String, Object?>{
          'applicationNo': created['applicationNo'],
          'phone': phone,
        });
        expect(result.status, HttpStatus.ok, reason: 'failed for $phone');
      }
    });

    test('an unknown number and a wrong phone answer alike', () async {
      final created = await file();
      final wrongPhone = await track(<String, Object?>{
        'applicationNo': created['applicationNo'],
        'phone': '08000000000',
      });
      final wrongNumber = await track(<String, Object?>{
        'applicationNo': 'TG-1999-0001',
        'phone': '08023449126',
      });

      expect(wrongPhone.status, HttpStatus.notFound);
      expect(wrongNumber.status, HttpStatus.notFound);
      // Identical bodies: otherwise the difference itself would let a caller
      // walk the sequence of application numbers and learn which exist.
      expect(wrongPhone.body['error'], wrongNumber.body['error']);
    });

    test('requires both the number and the phone', () async {
      final missingPhone = await track(<String, Object?>{
        'applicationNo': 'TG-2026-0001',
      });
      expect(missingPhone.status, HttpStatus.badRequest);

      final missingNumber = await track(<String, Object?>{
        'phone': '08023449126',
        'applicationNo': '   ',
      });
      expect(missingNumber.status, HttpStatus.badRequest);
      expect(missingNumber.body['errors'], isA<Map<String, Object?>>());
    });

    test('refuses any method but POST', () async {
      final response = await track_route.onRequest(
        _context(db: db, request: _jsonRequest('GET', trackUri)),
      );
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });

    test('keeps staff-only notes out of the applicant view', () async {
      final created = await file();
      final id = created['id'] as String;
      await status_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest(
            'PATCH',
            Uri.parse('http://localhost/applications/$id/status'),
            body: <String, Object?>{
              'status': 'pending',
              'remark': 'Called the applicant — internal office note',
              'receivedBy': 'Portal Admin',
            },
            headers: _bearer(_loginToken(db)),
          ),
        ),
        id,
      );

      final result = await track(<String, Object?>{
        'applicationNo': created['applicationNo'],
        'phone': '08023449126',
      });

      expect(result.status, HttpStatus.ok);
      expect(result.body['events'], isNotEmpty);
      expect(result.raw, isNot(contains('internal office note')));
      expect(result.raw, isNot(contains('Portal Admin')));
      expect((result.body['official'] as Map).containsKey('remarks'), isFalse);
      expect((result.body['official'] as Map).containsKey('receivedBy'), isFalse);
      for (final event in result.body['events'] as List<Object?>) {
        final map = event! as Map<String, Object?>;
        expect(map.containsKey('remark'), isFalse);
        expect(map.containsKey('staffUsername'), isFalse);
      }
    });
  });
}
