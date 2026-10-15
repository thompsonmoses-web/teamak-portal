import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

/// `POST /api/auth/logout` — revokes the caller's session token.
///
/// Revocation is what makes sign-out meaningful: without it the token stays
/// valid at the server until its 12-hour TTL lapses, so any copy of it keeps
/// working even after the staff member has "signed out".
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }

  final token = tokenFromHeader(context.request.headers['authorization']);
  // An already-unknown or absent token is treated as success so that
  // sign-out stays idempotent from the client's point of view.
  if (token != null) context.read<TeamakDatabase>().deleteSession(token);

  return jsonResponse(<String, Object?>{'status': 'signed_out'});
}
