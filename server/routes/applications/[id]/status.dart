import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';
import 'package:server/programmes.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }

  final staff = currentStaff(context);
  if (staff == null) return unauthorized();

  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object.');

  final status = '${body['status'] ?? ''}'.trim();
  if (!ApplicationStatus.staffSettable.contains(status)) {
    return badRequest(
      'Status must be one of: ${ApplicationStatus.staffSettable.join(', ')}.',
      errors: <String, String>{'status': 'Invalid status.'},
    );
  }

  final remark = _optionalString(body['remark']);
  final receivedBy = _optionalString(body['receivedBy']);
  final verificationDate = _optionalString(body['verificationDate']);
  final approvedProgrammeId = _optionalString(body['approvedProgrammeId']);
  final expectedDeliveryDate = _optionalString(body['expectedDeliveryDate']);

  if (approvedProgrammeId != null &&
      !Programme.ids.contains(approvedProgrammeId)) {
    return badRequest(
      'Unknown programme: $approvedProgrammeId',
      errors: <String, String>{'approvedProgrammeId': 'Invalid programme.'},
    );
  }

  int? approvedAmount;
  final rawAmount = body['approvedAmount'];
  if (rawAmount != null && '$rawAmount'.trim().isNotEmpty) {
    approvedAmount = int.tryParse('$rawAmount');
    if (approvedAmount == null || approvedAmount < 0) {
      return badRequest(
        'Approved amount must be a positive whole number of Naira.',
        errors: <String, String>{'approvedAmount': 'Invalid amount.'},
      );
    }
  }

  final db = context.read<TeamakDatabase>();
  try {
    final updated = db.updateApplicationStatus(
      id: id,
      status: status,
      remark: remark,
      receivedBy: receivedBy,
      verificationDate: verificationDate,
      approvedProgrammeId: approvedProgrammeId,
      approvedAmount: approvedAmount,
      expectedDeliveryDate: expectedDeliveryDate,
      staffUsername: '${staff['username']}',
    );
    if (updated == null) return notFound('Application not found.');

    return jsonResponse(<String, Object?>{
      ...updated,
      'events': db.applicationEvents(id),
    });
  } on DatabaseException catch (error) {
    return badRequest(error.message);
  } catch (error) {
    return serverError(error);
  }
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
