import 'package:flutter/material.dart';

/// Shared field validators for the application wizard.
String? requiredText(String? value, [String message = 'This field is required.']) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? phoneValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Phone number is required.';
  final digits = text.replaceAll(RegExp(r'[\s\-().]'), '');
  var normalized = digits;
  if (normalized.startsWith('+234')) {
    normalized = '0${normalized.substring(4)}';
  } else if (normalized.startsWith('234') && normalized.length == 13) {
    normalized = '0${normalized.substring(3)}';
  }
  if (!RegExp(r'^0[789]\d{9}$').hasMatch(normalized)) {
    return 'Enter a valid Nigerian number (e.g. 08023449126).';
  }
  return null;
}

String? optionalPhoneValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return phoneValidator(value);
}

String? ninValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'NIN is required.';
  if (!RegExp(r'^\d{11}$').hasMatch(text)) return 'NIN must be 11 digits.';
  return null;
}

String? fullNameValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Full name is required.';
  if (text.split(RegExp(r'\s+')).length < 2) {
    return 'Enter your first and last name.';
  }
  return null;
}

String? integerValidator(
  String? value, {
  required String message,
  int? min,
  int? max,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return message;
  final parsed = int.tryParse(text.replaceAll(',', ''));
  if (parsed == null) return 'Enter a whole number.';
  if (min != null && parsed < min) return 'Must be at least $min.';
  if (max != null && parsed > max) return 'Must be at most $max.';
  return null;
}

String? dateOfBirthValidator(DateTime? date) {
  if (date == null) return 'Date of birth is required.';
  final now = DateTime.now();
  if (date.isAfter(now)) return 'Date of birth cannot be in the future.';
  return null;
}

/// Formats a [DateTime] as the ISO date expected by the API.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Formats a date string as `dd/mm/yyyy` for display.
String displayDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
}) =>
    showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: first ?? DateTime(1950),
      lastDate: DateTime.now(),
    );
