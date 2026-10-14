import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

const sessionDuration = Duration(hours: 12);

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }

  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final username = '${body['username'] ?? ''}'.trim();
  final password = '${body['password'] ?? ''}';
  if (username.isEmpty || password.isEmpty) {
    return badRequest('Username and password are required.');
  }

  final result = login(
    context.read<TeamakDatabase>(),
    username: username,
    password: password,
  );

  if (result.invalidCredentials) {
    return unauthorized('Invalid username or password.');
  }

  final staff = result.staff!;
  return jsonResponse(<String, Object?>{
    'token': result.token,
    'expiresInSeconds': sessionDuration.inSeconds,
    'staff': <String, Object?>{
      'id': staff['id'],
      'username': staff['username'],
      'fullName': staff['fullName'],
      'role': staff['role'],
    },
  });
}
