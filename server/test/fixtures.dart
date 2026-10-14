/// A complete, valid application payload (sections A–H) for tests.
Map<String, dynamic> validApplication({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  final payload = <String, dynamic>{
    // Section A
    'fullName': 'Adebayo Ogundele',
    'phoneNumber': '08023449126',
    'whatsappNumber': '08031112222',
    'residentialAddress': '12 Ojoo Road, Ibadan',
    'areaCommunity': 'Ojoo',
    'dateOfBirth': '1990-05-14',
    'age': 36,
    'nin': '12345678901',
    'maritalStatus': 'married',
    // Section B
    'operationType': 'okada',
    'ridingExperience': 'y4_6',
    'currentVehicleOwnership': 'rented',
    'vehicleMakeModel': 'Bajaj Boxer 100',
    'parkRouteOperatingArea': 'Ojoo - UI Gate',
    'parkAssociationName': 'Ojoo Okada Park',
    'currentRemittance': '1,500 Naira daily',
    'averageWorkingDaysPerWeek': 6,
    // Section C
    'programmeId': 'okada_650',
    // Section D
    'amountToCommit': 650000,
    'sourceOfFunds': <String>['personal_savings', 'business_income'],
    'expectedDepositDate': '2026-11-01',
    'participatedBefore': false,
    // Section E
    'hasPassportPhotograph': true,
    'hasGovernmentIdOrNinSlip': true,
    'hasRiderOrAssociationRegistration': true,
    'hasProofOfResidentialAddress': false,
    'hasTwoPassportPhotographs': true,
    // Section F
    'nextOfKin': <String, dynamic>{
      'fullName': 'Folake Ogundele',
      'relationship': 'Wife',
      'phoneNumber': '08031234567',
      'address': '12 Ojoo Road, Ibadan',
    },
    // Section G
    'references': <Map<String, dynamic>>[
      <String, dynamic>{
        'fullName': 'Sunday Adeyemi',
        'relationship': 'Park Chairman',
        'phoneNumber': '08055556666',
        'address': 'Ojoo Park, Ibadan',
      },
      <String, dynamic>{
        'fullName': 'Grace Balogun',
        'relationship': 'Neighbour',
        'phoneNumber': '08077778888',
        'address': 'Aba Opa, Ibadan',
      },
    ],
    // Section H
    'declarationAccepted': true,
    'signatureName': 'Adebayo Ogundele',
    'declarationDate': '2026-10-09',
  };
  payload.addAll(overrides);
  return payload;
}
