import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:test/test.dart';

import '../../routes/staff/index.dart' as staff_route;
import '../../routes/staff/[id]/index.dart' as staff_detail_route;

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

/// A session for the seeded `admin` account.
String _adminToken(TeamakDatabase db) {
  final token = createSessionToken();
  db.createSession(
    token: token,
    staffId: db.staffByUsername('admin')!['id'] as int,
    ttl: const Duration(hours: 1),
  );
  return token;
}

/// A reviewer account with a live session — the role the guards must hold.
({int id, String token}) _reviewer(TeamakDatabase db) {
  final id = db.createStaff(
    username: 'temi',
    fullName: 'Temi Ayo',
    passwordHash: hashPassword('reviewpw'),
    role: 'reviewer',
  );
  final token = createSessionToken();
  db.createSession(token: token, staffId: id, ttl: const Duration(hours: 1));
  return (id: id, token: token);
}

void main() {
  late TeamakDatabase db;
  final staffUri = Uri.parse('http://localhost/staff');

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  Future<Response> list() => staff_route.onRequest(
        _context(db: db, request: _jsonRequest('GET', staffUri)),
      );

  Future<Response> create(
    Map<String, Object?> body, {
    required String token,
  }) =>
      staff_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('POST', staffUri,
              body: body, headers: _bearer(token)),
        ),
      );

  Future<Response> patch(
    int id,
    Map<String, Object?> body, {
    required String token,
  }) =>
      staff_detail_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('PATCH', Uri.parse('$staffUri/$id'),
              body: body, headers: _bearer(token)),
        ),
        '$id',
      );

  group('GET /staff', () {
    test('requires a session', () async {
      final response = await list();
      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('reviewers are refused', () async {
      final reviewer = _reviewer(db);
      final response = await staff_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('GET', staffUri,
              headers: _bearer(reviewer.token)),
        ),
      );
      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('lists accounts to an administrator without credentials', () async {
      _reviewer(db);
      final response = await staff_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('GET', staffUri,
              headers: _bearer(_adminToken(db))),
        ),
      );
      expect(response.statusCode, HttpStatus.ok);
      final raw = await response.body();
      expect(raw, isNot(contains('passwordHash')));
      expect(raw, isNot(contains(r'$2')));
      final body = jsonDecode(raw) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      expect(items, hasLength(2));
      expect((items.first as Map)['username'], 'admin');
      expect((items.first as Map)['role'], 'admin');
      expect((items.last as Map)['username'], 'temi');
      expect((items.last as Map)['createdAt'], isNotNull);
    });
  });

  group('POST /staff', () {
    test('creates an account that can then sign in', () async {
      final token = _adminToken(db);
      final response = await create(<String, Object?>{
        'username': 'temi',
        'fullName': 'Temi Ayo',
        'password': 'secret123',
        'role': 'reviewer',
      }, token: token);

      expect(response.statusCode, HttpStatus.created);
      final raw = await response.body();
      expect(raw, isNot(contains('passwordHash')));
      final body = jsonDecode(raw) as Map<String, dynamic>;
      expect(body['username'], 'temi');
      expect(body['role'], 'reviewer');

      final signedIn = login(db, username: 'temi', password: 'secret123');
      expect(signedIn.staff, isNotNull, reason: 'the new account can log in');
      expect(signedIn.invalidCredentials, isFalse);
    });

    test('rejects duplicates and weak input', () async {
      final token = _adminToken(db);
      final duplicate = await create(<String, Object?>{
        'username': 'admin',
        'fullName': 'Impostor',
        'password': 'secret123',
      }, token: token);
      expect(duplicate.statusCode, HttpStatus.conflict);

      final weak = await create(<String, Object?>{
        'username': 'x!',
        'fullName': '',
        'password': 'abc',
        'role': 'owner',
      }, token: token);
      expect(weak.statusCode, HttpStatus.badRequest);
      final body = jsonDecode(await weak.body()) as Map<String, dynamic>;
      expect((body['errors'] as Map).keys,
          containsAll(<String>['username', 'fullName', 'password', 'role']));
    });

    test('reviewers cannot create accounts', () async {
      final reviewer = _reviewer(db);
      final response = await create(<String, Object?>{
        'username': 'another',
        'fullName': 'Another Person',
        'password': 'secret123',
      }, token: reviewer.token);
      expect(response.statusCode, HttpStatus.forbidden);
      expect(db.staffByUsername('another'), isNull);
    });
  });

  group('PATCH /staff/:id', () {
    test('an administrator can promote a reviewer', () async {
      final reviewer = _reviewer(db);
      final response = await patch(reviewer.id, <String, Object?>{
        'role': 'admin',
      }, token: _adminToken(db));

      expect(response.statusCode, HttpStatus.ok);
      final body =
          jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['role'], 'admin');
      expect(db.staffById(reviewer.id)!['role'], 'admin');
    });

    test('the last administrator cannot be demoted', () async {
      final adminId = db.staffByUsername('admin')!['id'] as int;
      final response = await patch(adminId, <String, Object?>{
        'role': 'reviewer',
      }, token: _adminToken(db));

      expect(response.statusCode, HttpStatus.badRequest);
      final body =
          jsonDecode(await response.body()) as Map<String, dynamic>;
      expect('${body['error']}', contains('administrator'));
      expect(db.staffById(adminId)!['role'], 'admin',
          reason: 'the guard must hold the account, not just answer');
    });

    test('a password reset ends the account\u2019s sessions', () async {
      final reviewer = _reviewer(db);
      expect(db.staffForToken(reviewer.token), isNotNull);

      final response = await patch(reviewer.id, <String, Object?>{
        'password': 'newpass1',
      }, token: _adminToken(db));
      expect(response.statusCode, HttpStatus.ok);

      expect(db.staffForToken(reviewer.token), isNull,
          reason: 'the old session must die with the old password');
      final oldLogin =
          login(db, username: 'temi', password: 'reviewpw');
      expect(oldLogin.invalidCredentials, isTrue);
      final newLogin = login(db, username: 'temi', password: 'newpass1');
      expect(newLogin.invalidCredentials, isFalse);
    });

    test('reviewers cannot update accounts', () async {
      final reviewer = _reviewer(db);
      final response = await patch(reviewer.id, <String, Object?>{
        'fullName': 'Hacked Name',
      }, token: reviewer.token);
      expect(response.statusCode, HttpStatus.forbidden);
      expect(db.staffById(reviewer.id)!['fullName'], 'Temi Ayo');
    });

    test('unknown ids and other methods are refused', () async {
      final token = _adminToken(db);
      final missing = await patch(999, <String, Object?>{
        'role': 'admin',
      }, token: token);
      expect(missing.statusCode, HttpStatus.notFound);

      final wrongMethod = staff_detail_route.onRequest(
        _context(
          db: db,
          request: _jsonRequest('GET', Uri.parse('$staffUri/1'),
              headers: _bearer(token)),
        ),
        '1',
      );
      expect((await wrongMethod).statusCode, HttpStatus.methodNotAllowed);

      final nothing = await patch(
          db.staffByUsername('admin')!['id'] as int, <String, Object?>{},
          token: token);
      expect(nothing.statusCode, HttpStatus.badRequest);
    });
  });
}
