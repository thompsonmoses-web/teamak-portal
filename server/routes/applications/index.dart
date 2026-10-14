import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';
import 'package:server/programmes.dart';
import 'package:server/validation.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method == HttpMethod.post) return _create(context);
  if (method == HttpMethod.get) return _list(context);
  return Response.json(
    statusCode: 405,
    body: <String, Object?>{'error': 'Method not allowed.'},
  );
}

/// `POST /api/applications` — public submission of sections A–H.
Future<Response> _create(RequestContext context) async {
  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final errors = validateApplication(body);
  if (errors.isNotEmpty) {
    return badRequest('The application has validation errors.', errors: errors);
  }

  final db = context.read<TeamakDatabase>();
  try {
    final application = db.insertApplication(
      payload: body,
      programmeId: '${body['programmeId']}',
    );
    return jsonResponse(application, statusCode: HttpStatus.created);
  } catch (error) {
    return serverError(error);
  }
}

/// `GET /api/applications` — staff listing with search and status filter.
Future<Response> _list(RequestContext context) async {
  if (currentStaff(context) == null) return unauthorized();

  final query = context.request.uri.queryParameters;
  final status = query['status'];
  if (status != null && status.isNotEmpty && !ApplicationStatus.all.contains(status)) {
    return badRequest('Unknown status: $status');
  }

  final db = context.read<TeamakDatabase>();
  try {
    final limit = int.tryParse(query['limit'] ?? '') ?? 50;
    final offset = int.tryParse(query['offset'] ?? '') ?? 0;
    final results = db.listApplications(
      status: status,
      query: query['q'],
      limit: limit,
      offset: offset,
    );
    return jsonResponse(<String, Object?>{
      'total': db.countApplications(status: status, query: query['q']),
      'offset': offset,
      'results': results,
      'counts': db.staffCounts(),
    });
  } catch (error) {
    return serverError(error);
  }
}
