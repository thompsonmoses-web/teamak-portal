import 'package:dart_frog/dart_frog.dart';
import 'package:server/http_helpers.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }

  final staff = currentStaff(context);
  if (staff == null) return unauthorized();

  return jsonResponse(<String, Object?>{
    'id': staff['id'],
    'username': staff['username'],
    'fullName': staff['fullName'],
    'role': staff['role'],
  });
}
