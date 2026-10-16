import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';
import 'package:server/http_helpers.dart';

const String _unknownApplication =
    'No application matches that number and phone number.';

/// Collapses a Nigerian phone number to the `0XXXXXXXXXX` shape the applicant
/// would have typed, so `+234 802 344 9126`, `2348023449126` and
/// `08023449126` all compare as the same number.
String normalisePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('234')) digits = digits.substring(3);
  if (digits.length == 10) digits = '0$digits';
  return digits;
}

/// Lets an applicant fetch their own application without an account.
///
/// The phone number they submitted is the credential: application numbers run
/// in sequence, so without a matching phone anyone could walk `TG-2026-0001`,
/// `TG-2026-0002`, … and read every record. An unknown number and a wrong
/// phone therefore get the same 404 — the endpoint must not reveal which
/// numbers exist either.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: <String, Object?>{'error': 'Method not allowed.'},
    );
  }

  final body = await readJsonObject(context);
  if (body == null) return badRequest('Expected a JSON object body.');

  final applicationNo = '${body['applicationNo'] ?? ''}'.trim();
  final phone = '${body['phone'] ?? ''}'.trim();
  if (applicationNo.isEmpty || phone.isEmpty) {
    return badRequest(
      'Application number and phone number are required.',
      errors: <String, String>{
        if (applicationNo.isEmpty)
          'applicationNo': 'Application number is required.',
        if (phone.isEmpty) 'phone': 'Phone number is required.',
      },
    );
  }

  final db = context.read<TeamakDatabase>();
  final application = db.getApplicationByNo(applicationNo);
  if (application == null) return notFound(_unknownApplication);

  final answers = Map<String, dynamic>.from(
    application['application'] as Map? ?? const <Object?, Object?>{},
  );
  final submittedPhone = normalisePhone('${answers['phoneNumber'] ?? ''}');
  if (submittedPhone.isEmpty || submittedPhone != normalisePhone(phone)) {
    return notFound(_unknownApplication);
  }

  final official = Map<String, Object?>.from(
    application['official'] as Map? ?? const <Object?, Object?>{},
  );
  return jsonResponse(<String, Object?>{
    'id': application['id'],
    'applicationNo': application['applicationNo'],
    'status': application['status'],
    'programmeId': application['programmeId'],
    'createdAt': application['createdAt'],
    // The applicant's own answers, exactly as submitted: the dashboard shows
    // them back as the receipt summary did.
    'application': answers,
    // Only the outcome fields. `receivedBy`, `remarks` and `updatedBy` live
    // on the staff endpoint — they are internal notes, not the applicant's
    // to read.
    'official': <String, Object?>{
      for (final key in const <String>[
        'verificationStatus',
        'verificationDate',
        'approvedProgrammeId',
        'approvedAmount',
        'expectedDeliveryDate',
      ])
        if (official[key] != null) key: official[key],
    },
    // Transitions without the staff username or remark: the applicant sees
    // how the application moved, not who moved it or why internally.
    'events': <Map<String, Object?>>[
      for (final event in db.applicationEvents('${application['id']}'))
        <String, Object?>{
          'fromStatus': event['fromStatus'],
          'toStatus': event['toStatus'],
          'createdAt': event['createdAt'],
        },
    ],
    'documents': const <Object?>[],
  });
}
