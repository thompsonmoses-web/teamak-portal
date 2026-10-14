import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:server/database.dart';

/// Company inbox that receives contact-form submissions.
final _inbox = Platform.environment['CONTACT_EMAIL'] ??
    'Teamakgloblsolution33@gmail.com';

/// Gmail App Password (16 chars). Set via CONTACT_APP_PASSWORD env var.
/// Create one at: https://myaccount.google.com/apppasswords
String? get _appPassword => Platform.environment['CONTACT_APP_PASSWORD'];

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method not allowed');
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final name = '${body['name'] ?? ''}'.trim();
  final phone = '${body['phone'] ?? ''}'.trim();
  final email = '${body['email'] ?? ''}'.trim();
  final subject = '${body['subject'] ?? 'General enquiry'}'.trim();
  final message = '${body['message'] ?? ''}'.trim();

  if (name.isEmpty || phone.isEmpty || message.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Name, phone, and message are required.'},
    );
  }

  final db = context.read<TeamakDatabase>();

  try {
    db.insertContactMessage(
      name: name,
      phone: phone,
      email: email,
      subject: subject,
      message: message,
    );
  } catch (error) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to save your message. Please try again.'},
    );
  }

  // Send email notification (best-effort — message is saved either way).
  var emailSent = false;
  if (_appPassword != null && _appPassword!.isNotEmpty) {
    try {
      final smtp = gmail(_inbox, _appPassword!);
      final mail = Message()
        ..from = Address(_inbox, 'Teamak Portal')
        ..recipients.add(_inbox)
        ..subject = 'New Contact Message: $subject'
        ..text = '''
You received a new message from the Teamak Global Solutions website.

──────────────────────────
From:    $name
Phone:   $phone
Email:   ${email.isEmpty ? 'Not provided' : email}
Subject: $subject
──────────────────────────

$message

──────────────────────────
Sent from the website contact form.
${DateTime.now().toLocal()}''';

      await send(mail, smtp);
      emailSent = true;
    } catch (_) {
      // Email failed but message is saved in DB — staff can still see it.
    }
  }

  return Response.json(
    body: {
      'status': 'ok',
      'message': 'Thank you, $name! Your message has been received. '
          'We will get back to you shortly.',
      'emailSent': emailSent,
    },
  );
}
