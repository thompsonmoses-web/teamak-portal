import 'package:server/validation.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('validateApplication', () {
    test('accepts a complete application', () {
      expect(validateApplication(validApplication()), isEmpty);
    });

    test('requires applicant identification', () {
      final errors = validateApplication(
        validApplication(
          overrides: <String, dynamic>{
            'fullName': '',
            'phoneNumber': '',
            'nin': '12345',
            'areaCommunity': '',
          },
        ),
      );

      expect(errors.keys, containsAll(<String>[
        'fullName',
        'phoneNumber',
        'nin',
        'areaCommunity',
      ]));
    });

    test('rejects a single-word name', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'fullName': 'Adebayo',
      }));
      expect(errors['fullName'], contains('full name'));
    });

    test('rejects an under-age applicant', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'dateOfBirth': DateTime.now().subtract(const Duration(days: 365 * 17)).toIso8601String(),
      }));
      expect(errors['dateOfBirth'], contains('at least 18'));
    });

    test('rejects a future date of birth', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'dateOfBirth': '2099-01-01',
      }));
      expect(errors['dateOfBirth'], contains('future'));
    });

    test('accepts common Nigerian phone formats', () {
      for (final phone in <String>[
        '08023449126',
        '+2348023449126',
        '2348023449126',
        '07031112222',
        '09012345678',
        '0802 344 9126',
      ]) {
        expect(isValidNigerianPhone(phone), isTrue, reason: phone);
      }
    });

    test('rejects invalid phone numbers', () {
      for (final phone in <String>['', '12345', '081234567890', 'not-a-phone']) {
        expect(isValidNigerianPhone(phone), isFalse, reason: phone);
      }
    });

    test('requires an eleven digit NIN', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'nin': 'ABC12345678',
      }));
      expect(errors['nin'], contains('11 digits'));
    });

    test('requires a selected programme', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'programmeId': 'bike_100',
      }));
      expect(errors['programmeId'], isNotNull);
    });

    test('requires working days within 0-7', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'averageWorkingDaysPerWeek': 9,
      }));
      expect(errors['averageWorkingDaysPerWeek'], contains('between 0 and 7'));
    });

    test('requires a reason when other funding sources are used', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'sourceOfFunds': <String>['other'],
      }));
      expect(errors['sourceOfFundsOther'], isNotNull);
    });

    test('requires details of a previous programme', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'participatedBefore': true,
      }));
      expect(errors['previousProgrammeDetails'], isNotNull);
    });

    test('requires exactly two references', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'references': <Map<String, dynamic>>[
          <String, dynamic>{
            'fullName': 'Sunday Adeyemi',
            'relationship': 'Chairman',
            'phoneNumber': '08055556666',
            'address': 'Ojoo Park',
          },
        ],
      }));
      expect(errors['references'], contains('two references'));
    });

    test('validates reference phone numbers by index', () {
      final payload = validApplication();
      (payload['references'] as List<dynamic>)[1]['phoneNumber'] = '081';
      final errors = validateApplication(payload);
      expect(errors['references.1.phoneNumber'], isNotNull);
    });

    test('validates next of kin', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'nextOfKin': <String, dynamic>{
          'fullName': '',
          'relationship': '',
          'phoneNumber': '08',
          'address': '',
        },
      }));
      expect(
        errors.keys,
        containsAll(<String>[
          'nextOfKin.fullName',
          'nextOfKin.relationship',
          'nextOfKin.phoneNumber',
          'nextOfKin.address',
        ]),
      );
    });

    test('requires the declaration to be accepted', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'declarationAccepted': false,
        'signatureName': '',
      }));
      expect(errors['declarationAccepted'], isNotNull);
      expect(errors['signatureName'], isNotNull);
    });

    test('requires marital status other to be explained', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'maritalStatus': 'other',
      }));
      expect(errors['maritalStatusOther'], isNotNull);
    });

    test('requires vehicle arrangement to be explained when other', () {
      final errors =
          validateApplication(validApplication(overrides: <String, dynamic>{
        'currentVehicleOwnership': 'other',
      }));
      expect(errors['currentVehicleOther'], isNotNull);
    });
  });

  group('ageFrom', () {
    test('counts a birthday later in the year correctly', () {
      final age = ageFrom(DateTime(2000, 12, 31), now: DateTime(2026, 1, 1));
      expect(age, 25);
    });

    test('counts a birthday already passed', () {
      final age = ageFrom(DateTime(2000, 1, 1), now: DateTime(2026, 6, 1));
      expect(age, 26);
    });
  });
}
