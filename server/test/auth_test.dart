import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:test/test.dart';

void main() {
  late TeamakDatabase db;

  setUp(() {
    db = TeamakDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  group('password hashing', () {
    test('hashes and verifies', () {
      final hash = hashPassword('s3cret-pass');
      expect(hash, isNot('s3cret-pass'));
      expect(hash, startsWith(r'$2'));
      expect(verifyPassword('s3cret-pass', hash), isTrue);
      expect(verifyPassword('wrong', hash), isFalse);
    });

    test('returns false for a malformed hash', () {
      expect(verifyPassword('anything', 'not-a-hash'), isFalse);
    });

    test('produces a unique salt per hash', () {
      expect(hashPassword('same'), isNot(hashPassword('same')));
    });
  });

  group('login', () {
    test('issues a token for valid credentials', () {
      final result = login(db, username: 'admin', password: 'admin123');
      expect(result.error, isNull);
      expect(result.token, isNotNull);
      expect(result.staff!['username'], 'admin');
      expect(db.staffForToken(result.token!), isNotNull);
    });

    test('rejects a wrong password', () {
      final result = login(db, username: 'admin', password: 'wrong');
      expect(result.invalidCredentials, isTrue);
      expect(result.token, isNull);
    });

    test('rejects an unknown user', () {
      final result = login(db, username: 'ghost', password: 'admin123');
      expect(result.invalidCredentials, isTrue);
    });
  });

  group('staffFromHeader', () {
    test('parses a bearer token', () {
      final token = createSessionToken();
      db.createSession(
        token: token,
        staffId: db.staffByUsername('admin')!['id'] as int,
        ttl: const Duration(hours: 1),
      );

      final staff = staffFromHeader(db, 'Bearer $token');
      expect(staff?['username'], 'admin');
      expect(staffFromHeader(db, 'Bearer wrong'), isNull);
      expect(staffFromHeader(db, token), isNull, reason: 'needs the prefix');
      expect(staffFromHeader(db, null), isNull);
      expect(staffFromHeader(db, 'Bearer '), isNull);
    });
  });

  group('session tokens', () {
    test('are random and url safe', () {
      final first = createSessionToken();
      final second = createSessionToken();
      expect(first, isNot(second));
      expect(first.length, greaterThan(20));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(first), isTrue);
    });
  });
}
