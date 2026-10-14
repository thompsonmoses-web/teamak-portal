import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }
  if (currentStaff(context) == null) return unauthorized();

  final db = context.read<TeamakDatabase>();
  final application = db.getApplicationById(id);
  if (application == null) return notFound('Application not found.');

  return jsonResponse(<String, Object?>{
    ...application,
    'events': db.applicationEvents(id),
    'documents': db.documentsFor(id),
  });
}
