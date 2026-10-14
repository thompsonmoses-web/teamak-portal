import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server/database.dart';
import 'package:test/test.dart';

import '../../routes/auth/login.dart' as login_route;
import '../../routes/auth/me.dart' as me_route;
import '../../routes/programmes/index.dart' as programmes_route;

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

void main() {
  late TeamakDatabase db;

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  group('GET /programmes', () {
    test('returns the three ownership tiers', () async {
      final response = programmes_route.onRequest(_MockRequestContext());
      expect(response.statusCode, HttpStatus.ok);

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      final programmes = body['programmes'] as List<dynamic>;
      expect(programmes, hasLength(3));
      expect(
        programmes.map((p) => (p as Map<String, dynamic>)['id']),
        containsAll(<String>['okada_650', 'okada_400', 'maruwa_2300']),
      );
      expect(body['depositNote'], contains('one-time deposit'));
    });
  });

  group('POST /auth/login', () {
    test('issues a token for the seeded administrator', () async {
      final response = await login_route.onRequest(
        _context(
          db: db,
          request: Request(
            'POST',
            Uri.parse('http://localhost/auth/login'),
            headers: <String, Object>{'content-type': 'application/json'},
            body: jsonEncode(<String, Object?>{
              'username': 'admin',
              'password': 'admin123',
            }),
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['token'], isNotNull);
      expect((body['staff'] as Map<String, dynamic>)['username'], 'admin');
      expect(db.staffForToken('${body['token']}'), isNotNull);
    });

    test('rejects bad credentials', () async {
      final response = await login_route.onRequest(
        _context(
          db: db,
          request: Request(
            'POST',
            Uri.parse('http://localhost/auth/login'),
            headers: <String, Object>{'content-type': 'application/json'},
            body: jsonEncode(<String, Object?>{
              'username': 'admin',
              'password': 'nope',
            }),
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.unauthorized);
      expect(db.countApplications(), 0);
    });

    test('rejects missing fields', () async {
      final response = await login_route.onRequest(
        _context(
          db: db,
          request: Request(
            'POST',
            Uri.parse('http://localhost/auth/login'),
            headers: <String, Object>{'content-type': 'application/json'},
            body: jsonEncode(<String, Object?>{}),
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.badRequest);
    });
  });

  group('GET /auth/me', () {
    test('returns the authenticated staff member', () async {
      const token = 'me-token';
      db.createSession(
        token: token,
        staffId: db.staffByUsername('admin')!['id'] as int,
        ttl: const Duration(hours: 1),
      );

      final response = me_route.onRequest(
        _context(
          db: db,
          request: Request.get(
            Uri.parse('http://localhost/auth/me'),
            headers: <String, Object>{'authorization': 'Bearer $token'},
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['username'], 'admin');
    });

    test('rejects anonymous requests', () async {
      final response = me_route.onRequest(
        _context(
          db: db,
          request: Request.get(Uri.parse('http://localhost/auth/me')),
        ),
      );
      expect(response.statusCode, HttpStatus.unauthorized);
    });
  });
}
