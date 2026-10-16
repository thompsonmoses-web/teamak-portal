import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

const List<String> _roles = <String>['admin', 'reviewer'];

/// Administrator-only update of one staff account: name, role or password.
///
/// A password change ends that account's sessions on the spot — a reset that
/// left the old token running until it aged out would not be a reset.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }
  final staff = currentStaff(context);
  if (staff == null) return unauthorized();
  if (staff['role'] != 'admin') return forbidden();

  final staffId = int.tryParse(id);
  final db = context.read<TeamakDatabase>();
  final existing = staffId == null ? null : db.staffById(staffId);
  if (staffId == null || existing == null) {
    return notFound('Staff member not found.');
  }

  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final fullName =
      body['fullName'] == null ? null : '${body['fullName']}'.trim();
  final role = body['role'] == null ? null : '${body['role']}'.trim();
  final password = body['password'] == null ? null : '${body['password']}';

  if (fullName == null && role == null && password == null) {
    return badRequest('Nothing to update.');
  }

  final errors = <String, String>{};
  if (fullName != null && fullName.isEmpty) {
    errors['fullName'] = 'Full name cannot be empty.';
  }
  if (role != null && !_roles.contains(role)) {
    errors['role'] = 'Choose admin or reviewer.';
  }
  if (password != null && password.length < 6) {
    errors['password'] = 'Use at least 6 characters.';
  }
  if (errors.isNotEmpty) {
    return badRequest('Check the highlighted fields.', errors: errors);
  }

  // Never let the last administrator drop their own rights: the account
  // that would notice the mistake is the one that could no longer fix it.
  if (role != null &&
      role != 'admin' &&
      existing['role'] == 'admin' &&
      db.countAdmins() <= 1) {
    return badRequest(
      'At least one administrator must remain.',
      errors: <String, String>{
        'role': 'The last administrator cannot be demoted.',
      },
    );
  }

  db.updateStaff(
    id: staffId,
    fullName: fullName,
    role: role,
    passwordHash: password == null ? null : hashPassword(password),
  );
  if (password != null) db.deleteSessionsFor(staffId);

  return jsonResponse(db.staffSummaryById(staffId));
}
