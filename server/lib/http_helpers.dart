import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'auth.dart';
import 'database.dart';

/// Shared HTTP helpers for the Teamak API routes.

Response jsonResponse(Object? body, {int statusCode = HttpStatus.ok}) =>
    Response.json(body: body, statusCode: statusCode);

Response badRequest(String message, {Map<String, Object?>? errors}) =>
    Response.json(
      statusCode: HttpStatus.badRequest,
      body: <String, Object?>{
        'error': message,
        if (errors != null) 'errors': errors,
      },
    );

Response unauthorized([String message = 'Authentication required.']) =>
    Response.json(
      statusCode: HttpStatus.unauthorized,
      body: <String, Object?>{'error': message},
    );

Response notFound([String message = 'Resource not found.']) => Response.json(
      statusCode: HttpStatus.notFound,
      body: <String, Object?>{'error': message},
    );

Response serverError(Object error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: <String, Object?>{'error': 'Unexpected server error.'},
    );

/// Resolves the authenticated staff member from the `Authorization` header.
Map<String, Object?>? currentStaff(RequestContext context) =>
    staffFromHeader(
      context.read<TeamakDatabase>(),
      context.request.headers['authorization'],
    );

/// Reads the request body as a JSON object, or `null` when it is not one.
Future<Map<String, dynamic>?> readJsonObject(RequestContext context) async {
  try {
    final dynamic decoded = await context.request.json();
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  } catch (_) {
    return null;
  }
}

/// Decodes a base64 document payload, returning bytes or `null`.
List<int>? decodeBase64File(String value) {
  try {
    return base64Decode(value.replaceAll(RegExp(r'\s'), ''));
  } catch (_) {
    return null;
  }
}

/// Filesystem-safe name for an uploaded document.
String safeFileName(String name, {String fallback = 'document'}) {
  final cleaned = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\.\.+'), '.')
      .trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return fallback;
  return cleaned.length > 120 ? cleaned.substring(cleaned.length - 120) : cleaned;
}
