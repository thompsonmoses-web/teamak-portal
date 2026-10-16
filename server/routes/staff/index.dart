import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

const List<String> _roles = <String>['admin', 'reviewer'];

/// Administrator-only staff directory: list accounts and create new ones.
///
/// Reviewers use the rest of the staff area but never this route — who can
/// sign in is an administrator's decision, and this guard is what makes that
/// true. The app merely hides the door; the API is where it is locked.
Future<Response> onRequest(RequestContext context) async {
  final staff = currentStaff(context);
  if (staff == null) return unauthorized();
  if (staff['role'] != 'admin') return forbidden();

  final db = context.read<TeamakDatabase>();
  if (context.request.method == HttpMethod.get) {
    return jsonResponse(<String, Object?>{'items': db.listStaff()});
  }
  if (context.request.method == HttpMethod.post) {
    return _create(context, db);
  }
  return Response.json(
    statusCode: 405,
    body: <String, Object?>{'error': 'Method not allowed.'},
  );
}

Future<Response> _create(RequestContext context, TeamakDatabase db) async {
  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final username = '${body['username'] ?? ''}'.trim();
  final fullName = '${body['fullName'] ?? ''}'.trim();
  final password = '${body['password'] ?? ''}';
  final role = '${body['role'] ?? 'reviewer'}'.trim();

  final errors = <String, String>{};
  if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(username)) {
    errors['username'] =
        'Use 3–32 letters, numbers, dots, dashes or underscores.';
  }
  if (fullName.isEmpty) errors['fullName'] = 'Full name is required.';
  if (password.length < 6) errors['password'] = 'Use at least 6 characters.';
  if (!_roles.contains(role)) errors['role'] = 'Choose admin or reviewer.';
  if (errors.isNotEmpty) {
    return badRequest('Check the highlighted fields.', errors: errors);
  }

  if (db.staffByUsername(username) != null) {
    return Response.json(
      statusCode: HttpStatus.conflict,
      body: <String, Object?>{
        'error': 'That username is already taken.',
        'errors': <String, String>{'username': 'Already taken.'},
      },
    );
  }

  final id = db.createStaff(
    username: username,
    fullName: fullName,
    passwordHash: hashPassword(password),
    role: role,
  );
  return jsonResponse(
    db.staffSummaryById(id),
    statusCode: HttpStatus.created,
  );
}
