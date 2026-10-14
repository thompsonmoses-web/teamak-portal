import 'programmes.dart';

/// Validation for the application payload (sections A–H).
///
/// Returns a map of `field.path` → human readable error. An empty map means
/// the payload is valid.
Map<String, String> validateApplication(Map<String, dynamic> data) {
  final errors = <String, String>{};

  void requireString(String path, {int maxLength = 200}) {
    final value = _text(data, path);
    if (value.isEmpty) {
      errors[path] = 'This field is required.';
    } else if (value.length > maxLength) {
      errors[path] = 'Must be at most $maxLength characters.';
    }
  }

  // ── Section A ────────────────────────────────────────────────────────────
  requireString('fullName', maxLength: 120);
  if (_text(data, 'fullName').isNotEmpty &&
      _text(data, 'fullName').trim().split(RegExp(r'\s+')).length < 2) {
    errors['fullName'] = 'Enter your full name (first and last).';
  }

  final phone = _text(data, 'phoneNumber');
  if (phone.isEmpty) {
    errors['phoneNumber'] = 'This field is required.';
  } else if (!isValidNigerianPhone(phone)) {
    errors['phoneNumber'] = 'Enter a valid Nigerian phone number (e.g. 08023449126).';
  }

  final whatsapp = _text(data, 'whatsappNumber');
  if (whatsapp.isNotEmpty && !isValidNigerianPhone(whatsapp)) {
    errors['whatsappNumber'] = 'Enter a valid phone number.';
  }

  requireString('residentialAddress', maxLength: 300);
  requireString('areaCommunity', maxLength: 120);

  final dob = _text(data, 'dateOfBirth');
  if (dob.isEmpty) {
    errors['dateOfBirth'] = 'This field is required.';
  } else {
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) {
      errors['dateOfBirth'] = 'Use the format YYYY-MM-DD.';
    } else if (parsed.isAfter(DateTime.now())) {
      errors['dateOfBirth'] = 'Date of birth cannot be in the future.';
    } else if (ageFrom(parsed) < 18) {
      errors['dateOfBirth'] = 'Applicants must be at least 18 years old.';
    }
  }

  final age = _int(data, 'age');
  if (age != null && (age < 18 || age > 100)) {
    errors['age'] = 'Age must be between 18 and 100.';
  }

  final nin = _text(data, 'nin');
  if (nin.isEmpty) {
    errors['nin'] = 'This field is required.';
  } else if (!RegExp(r'^\d{11}$').hasMatch(nin)) {
    errors['nin'] = 'NIN must be exactly 11 digits.';
  }

  const maritalOptions = {'single', 'married', 'other'};
  final marital = _text(data, 'maritalStatus');
  if (!maritalOptions.contains(marital)) {
    errors['maritalStatus'] = 'Select a marital status.';
  } else if (marital == 'other' && _text(data, 'maritalStatusOther').isEmpty) {
    errors['maritalStatusOther'] = 'Please specify your marital status.';
  }

  // ── Section B ────────────────────────────────────────────────────────────
  if (!const {'okada', 'maruwa'}.contains(_text(data, 'operationType'))) {
    errors['operationType'] = 'Select your type of operation.';
  }

  if (!const {'lt1', 'y1_3', 'y4_6', 'y7_plus'}
      .contains(_text(data, 'ridingExperience'))) {
    errors['ridingExperience'] = 'Select your years of riding experience.';
  }

  const ownershipOptions = {'owned', 'rented', 'hired_leased', 'other'};
  final ownership = _text(data, 'currentVehicleOwnership');
  if (!ownershipOptions.contains(ownership)) {
    errors['currentVehicleOwnership'] = 'Select how you currently access your vehicle.';
  } else if (ownership == 'other' && _text(data, 'currentVehicleOther').isEmpty) {
    errors['currentVehicleOther'] = 'Please specify your vehicle arrangement.';
  }

  requireString('parkRouteOperatingArea');
  requireString('parkAssociationName');
  requireString('currentRemittance', maxLength: 80);

  final days = _int(data, 'averageWorkingDaysPerWeek');
  if (days == null) {
    errors['averageWorkingDaysPerWeek'] = 'This field is required.';
  } else if (days < 0 || days > 7) {
    errors['averageWorkingDaysPerWeek'] = 'Working days must be between 0 and 7.';
  }

  // ── Section C ────────────────────────────────────────────────────────────
  final programmeId = _text(data, 'programmeId');
  if (!Programme.ids.contains(programmeId)) {
    errors['programmeId'] = 'Select exactly one programme.';
  }

  // ── Section D ────────────────────────────────────────────────────────────
  final amount = _int(data, 'amountToCommit');
  if (amount == null) {
    errors['amountToCommit'] = 'This field is required.';
  } else if (amount <= 0) {
    errors['amountToCommit'] = 'Amount must be greater than zero.';
  }

  const fundSources = {
    'personal_savings',
    'business_income',
    'family_support',
    'other',
  };
  final sources = _textList(data, 'sourceOfFunds');
  if (sources.isEmpty) {
    errors['sourceOfFunds'] = 'Select at least one source of funds.';
  } else if (sources.any((s) => !fundSources.contains(s))) {
    errors['sourceOfFunds'] = 'One of the selected sources is not recognised.';
  } else if (sources.contains('other') &&
      _text(data, 'sourceOfFundsOther').isEmpty) {
    errors['sourceOfFundsOther'] = 'Please specify your other source of funds.';
  }

  final depositDate = _text(data, 'expectedDepositDate');
  if (depositDate.isEmpty) {
    errors['expectedDepositDate'] = 'This field is required.';
  } else if (DateTime.tryParse(depositDate) == null) {
    errors['expectedDepositDate'] = 'Use the format YYYY-MM-DD.';
  }

  final participated = _bool(data, 'participatedBefore');
  if (participated == null) {
    errors['participatedBefore'] = 'Please answer yes or no.';
  } else if (participated && _text(data, 'previousProgrammeDetails').isEmpty) {
    errors['previousProgrammeDetails'] = 'State which Teamak programme you joined before.';
  }

  // ── Section E ────────────────────────────────────────────────────────────
  for (final key in const <String>[
    'hasPassportPhotograph',
    'hasGovernmentIdOrNinSlip',
    'hasRiderOrAssociationRegistration',
    'hasProofOfResidentialAddress',
    'hasTwoPassportPhotographs',
  ]) {
    if (_bool(data, key) == null) {
      errors[key] = 'Indicate whether this document is provided.';
    }
  }

  // ── Section F ────────────────────────────────────────────────────────────
  requireString('nextOfKin.fullName', maxLength: 120);
  requireString('nextOfKin.relationship', maxLength: 60);
  final kinPhone = _text(data, 'nextOfKin.phoneNumber');
  if (kinPhone.isEmpty) {
    errors['nextOfKin.phoneNumber'] = 'This field is required.';
  } else if (!isValidNigerianPhone(kinPhone)) {
    errors['nextOfKin.phoneNumber'] = 'Enter a valid Nigerian phone number.';
  }
  requireString('nextOfKin.address', maxLength: 300);

  // ── Section G ────────────────────────────────────────────────────────────
  final references = _refList(data, 'references');
  if (references.length != 2) {
    errors['references'] = 'Provide exactly two references.';
  } else {
    for (var i = 0; i < references.length; i++) {
      final ref = references[i];
      if (_text(ref, 'fullName').isEmpty) {
        errors['references.$i.fullName'] = 'This field is required.';
      }
      if (_text(ref, 'relationship').isEmpty) {
        errors['references.$i.relationship'] = 'This field is required.';
      }
      final refPhone = _text(ref, 'phoneNumber');
      if (refPhone.isEmpty) {
        errors['references.$i.phoneNumber'] = 'This field is required.';
      } else if (!isValidNigerianPhone(refPhone)) {
        errors['references.$i.phoneNumber'] = 'Enter a valid Nigerian phone number.';
      }
      if (_text(ref, 'address').isEmpty) {
        errors['references.$i.address'] = 'This field is required.';
      }
    }
  }

  // ── Section H ────────────────────────────────────────────────────────────
  if (_bool(data, 'declarationAccepted') != true) {
    errors['declarationAccepted'] = 'You must accept the declaration to apply.';
  }
  if (_text(data, 'signatureName').isEmpty) {
    errors['signatureName'] = 'Type your full name as your signature.';
  }
  final signDate = _text(data, 'declarationDate');
  if (signDate.isEmpty) {
    errors['declarationDate'] = 'This field is required.';
  } else if (DateTime.tryParse(signDate) == null) {
    errors['declarationDate'] = 'Use the format YYYY-MM-DD.';
  }

  return errors;
}

/// Accepts `0XXXXXXXXXX`, `+234XXXXXXXXXX`, `234XXXXXXXXXX` and `XXXXXXXXXX`
/// (10 digit) Nigerian numbers, tolerating spaces, dashes and parentheses.
bool isValidNigerianPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?\d+$').hasMatch(digits)) return false;
  var normalized = digits;
  if (normalized.startsWith('+234')) {
    normalized = '0${normalized.substring(4)}';
  } else if (normalized.startsWith('234') && normalized.length == 13) {
    normalized = '0${normalized.substring(3)}';
  }
  return RegExp(r'^0[789]\d{9}$').hasMatch(normalized);
}

int ageFrom(DateTime dateOfBirth, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dateOfBirth.year;
  if (today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
    age--;
  }
  return age;
}

String _text(Map<String, dynamic> data, String path) {
  final value = _lookup(data, path);
  if (value == null) return '';
  return value.toString().trim();
}

int? _int(Map<String, dynamic> data, String path) {
  final value = _lookup(data, path);
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

bool? _bool(Map<String, dynamic> data, String path) {
  final value = _lookup(data, path);
  if (value == null) return null;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

List<String> _textList(Map<String, dynamic> data, String path) {
  final value = _lookup(data, path);
  if (value is List) {
    return value.map((e) => e.toString().trim()).toList();
  }
  if (value == null) return const <String>[];
  final text = value.toString().trim();
  if (text.isEmpty) return const <String>[];
  return text.split(',').map((e) => e.trim()).toList();
}

List<Map<String, dynamic>> _refList(Map<String, dynamic> data, String path) {
  final value = _lookup(data, path);
  if (value is! List) return const <Map<String, dynamic>>[];
  final references = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map<Object?, Object?>) {
      references.add(Map<String, dynamic>.from(item));
    }
  }
  return references;
}

dynamic _lookup(Map<String, dynamic> data, String path) {
  final parts = path.split('.');
  dynamic current = data;
  for (final part in parts) {
    if (current is Map) {
      current = current[part];
    } else {
      return null;
    }
  }
  return current;
}
