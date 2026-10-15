import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';

import 'database.dart';

/// Hashes a plaintext password with bcrypt.
String hashPassword(String password) =>
    BCrypt.hashpw(password, BCrypt.gensalt());

/// Verifies [password] against a bcrypt [hash].
bool verifyPassword(String password, String hash) {
  try {
    return BCrypt.checkpw(password, hash);
  } catch (_) {
    return false;
  }
}

/// Generates a cryptographically random session token.
String createSessionToken([int bytes = 32]) {
  final random = Random.secure();
  final buffer = List<int>.generate(bytes, (_) => random.nextInt(256));
  return base64UrlEncode(buffer).replaceAll('=', '');
}

class AuthResult {
  AuthResult.success(this.token, this.staff)
      : error = null,
        invalidCredentials = false;
  AuthResult.invalid()
      : token = null,
        staff = null,
        error = 'Invalid username or password.',
        invalidCredentials = true;

  final String? token;
  final Map<String, Object?>? staff;
  final String? error;
  final bool invalidCredentials;
}

/// Authenticates a staff member and opens a session lasting [ttl].
AuthResult login(
  TeamakDatabase db, {
  required String username,
  required String password,
  Duration ttl = const Duration(hours: 12),
}) {
  final staff = db.staffByUsername(username.trim());
  if (staff == null) return AuthResult.invalid();
  final storedHash = staff['passwordHash'];
  if (storedHash is! String) return AuthResult.invalid();
  if (!verifyPassword(password, storedHash)) return AuthResult.invalid();

  final staffId = staff['id'];
  if (staffId is! int) return AuthResult.invalid();

  final token = createSessionToken();
  db.createSession(token: token, staffId: staffId, ttl: ttl);
  return AuthResult.success(token, staff);
}

/// Extracts the raw token from an `Authorization: Bearer <token>` header.
String? tokenFromHeader(String? header) {
  if (header == null) return null;
  final trimmed = header.trim();
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    final token = trimmed.substring(7).trim();
    return token.isEmpty ? null : token;
  }
  return null;
}

/// Resolves the staff member behind an `Authorization: Bearer <token>` header.
Map<String, Object?>? staffFromHeader(TeamakDatabase db, String? header) {
  final token = tokenFromHeader(header);
  if (token == null) return null;
  return db.staffForToken(token);
}
