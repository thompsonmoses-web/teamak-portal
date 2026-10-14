import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

/// Document kinds accepted by Section E of the application form.
const documentKinds = <String>{
  'passport_photograph',
  'government_id',
  'rider_registration',
  'address_proof',
  'two_passport_photographs',
};

/// Directory where uploaded documents are written. Tests may override it.
Directory? uploadDirectoryOverride;

Directory uploadDirectory() {
  final override = uploadDirectoryOverride;
  if (override != null) return override..createSync(recursive: true);
  final path = Platform.environment['TEAMAK_UPLOADS'] ?? 'uploads';
  return Directory(path)..createSync(recursive: true);
}

Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method == HttpMethod.post) return _upload(context, id);
  if (method == HttpMethod.get) return _list(context, id);
  return Response.json(
    statusCode: 405,
    body: <String, Object?>{'error': 'Method not allowed.'},
  );
}

Future<Response> _list(RequestContext context, String id) async {
  if (currentStaff(context) == null) return unauthorized();
  final db = context.read<TeamakDatabase>();
  if (!db.applicationExists(id)) return notFound('Application not found.');
  return jsonResponse(<String, Object?>{'documents': db.documentsFor(id)});
}

/// `POST /api/applications/:id/documents`
///
/// Body: `{ "kind": "<section E kind>", "fileName": "...", "content": "<base64>" }`
Future<Response> _upload(RequestContext context, String id) async {
  if (currentStaff(context) == null) return unauthorized();

  final db = context.read<TeamakDatabase>();
  if (!db.applicationExists(id)) return notFound('Application not found.');

  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final kind = '${body['kind'] ?? ''}'.trim();
  if (!documentKinds.contains(kind)) {
    return badRequest(
      'Document kind must be one of: ${documentKinds.join(', ')}.',
      errors: <String, String>{'kind': 'Invalid document kind.'},
    );
  }

  final fileName = safeFileName('${body['fileName'] ?? ''}');
  final content = '${body['content'] ?? ''}';
  if (content.isEmpty) {
    return badRequest(
      'Document content is required.',
      errors: <String, String>{'content': 'Missing base64 content.'},
    );
  }

  final bytes = decodeBase64File(content);
  if (bytes == null) {
    return badRequest(
      'Document content is not valid base64.',
      errors: <String, String>{'content': 'Invalid base64.'},
    );
  }

  try {
    final directory = uploadDirectory();
    final storedName =
        '${DateTime.now().microsecondsSinceEpoch}_$fileName';
    final file = File('${directory.path}${Platform.pathSeparator}$storedName');
    file.writeAsBytesSync(bytes, flush: true);

    final documentId = db.insertDocument(
      applicationId: id,
      kind: kind,
      fileName: fileName,
      storedPath: file.path,
    );

    return jsonResponse(
      <String, Object?>{
        'id': documentId,
        'kind': kind,
        'fileName': fileName,
        'sizeBytes': bytes.length,
      },
      statusCode: HttpStatus.created,
    );
  } catch (error) {
    return serverError(error);
  }
}
