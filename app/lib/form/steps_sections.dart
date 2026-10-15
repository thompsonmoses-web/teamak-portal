import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'form_utils.dart';
import 'steps.dart';

/// Section C — programme selection.
class ProgrammeStep extends StatelessWidget {
  const ProgrammeStep({
    super.key,
    required this.read,
    required this.write,
    required this.programmes,
  });

  final DataReader read;
  final DataWriter write;
  final List<Programme> programmes;

  @override
  Widget build(BuildContext context) {
    final selected = read('programmeId') as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Choose your programme',
          subtitle: 'Pick ONE programme below.',
        ),
        for (final programme in programmes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => write('programmeId', programme.id),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected == programme.id
                      ? TeamakColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  border: Border.all(
                    color: selected == programme.id
                        ? TeamakColors.primary
                        : const Color(0xFFE3E8E6),
                    width: selected == programme.id ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selected == programme.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected == programme.id
                          ? TeamakColors.primary
                          : TeamakColors.subtle,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            programme.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TeamakColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${programme.depositLabel} deposit → '
                            '${programme.months} months → ${programme.asset}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            programme.summary,
                            style: const TextStyle(
                              color: TeamakColors.subtle,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (selected == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Select one programme to continue.',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}

/// Section D — how the applicant funds the deposit.
///
/// The API rejects an application that omits any of these, so they cannot be
/// left to the final step.
class FundingStep extends StatelessWidget {
  const FundingStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  static const _sources = <MapEntry<String, String>>[
    MapEntry('personal_savings', 'Personal savings'),
    MapEntry('business_income', 'Business income'),
    MapEntry('family_support', 'Family support'),
    MapEntry('other', 'Other'),
  ];

  List<String> get _selected =>
      (read('sourceOfFunds') as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList();

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final depositDate = read('expectedDepositDate') as String?;
    final deposit = DateTime.tryParse(depositDate ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Funding your deposit',
          subtitle: 'Tell us how you plan to raise the one-time deposit.',
        ),
        const FieldLabel(label: 'Source of funds', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            for (final source in _sources)
              FilterChip(
                label: Text(source.value, style: const TextStyle(fontSize: 14)),
                selected: selected.contains(source.key),
                selectedColor: TeamakColors.primary.withValues(alpha: 0.12),
                onSelected: (on) {
                  final next = List<String>.from(selected);
                  if (on) {
                    next.add(source.key);
                  } else {
                    next.remove(source.key);
                  }
                  write('sourceOfFunds', next);
                },
              ),
          ],
        ),
        if (selected.contains('other')) ...<Widget>[
          TextFormField(
            initialValue: read('sourceOfFundsOther') as String?,
            decoration: const InputDecoration(labelText: 'Please specify *'),
            validator: (v) => requiredText(v),
            onChanged: (v) => write('sourceOfFundsOther', v),
          ),
        ],
        const SizedBox(height: 14),
        // Day-based bounds: the field compares whole calendar days, so the
        // deposit can legitimately be due today.
        DateField(
          label: 'Expected deposit date *',
          value: depositDate,
          onChanged: (v) => write('expectedDepositDate', v),
          first: today,
          last: today.add(const Duration(days: 365)),
        ),
        const SizedBox(height: 6),
        Text(
          deposit == null
              ? 'When you expect to make the deposit.'
              : 'Deposits are accepted on or before '
                  '${displayDate(isoDate(deposit))}.',
          style: const TextStyle(color: TeamakColors.subtle, fontSize: 13),
        ),
        const SizedBox(height: 10),
        YesNoGroup(
          label: 'Have you taken part in a Teamak programme before?',
          required: true,
          value: read('participatedBefore') as bool?,
          onChanged: (v) => write('participatedBefore', v),
        ),
        if (read('participatedBefore') == true) ...<Widget>[
          TextFormField(
            initialValue: read('previousProgrammeDetails') as String?,
            decoration: const InputDecoration(
              labelText: 'Which programme? *',
            ),
            validator: (v) => requiredText(v),
            onChanged: (v) => write('previousProgrammeDetails', v),
          ),
        ],
      ],
    );
  }
}

/// Section E — documents the applicant can produce.
///
/// The API requires an answer for every one of these; a missing answer is a
/// validation error, and "No" is a valid answer.
class DocumentsStep extends StatelessWidget {
  const DocumentsStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  /// API field name, human label, and a short description of each document.
  static const documents = <(String, String, String)>[
    (
      'hasPassportPhotograph',
      'Passport photograph',
      'A recent colour photograph, white background.',
    ),
    (
      'hasGovernmentIdOrNinSlip',
      'Government ID or NIN slip',
      'National ID card, driver’s licence, or NIN slip.',
    ),
    (
      'hasRiderOrAssociationRegistration',
      'Rider / association registration',
      'Your park or riders’ association registration card.',
    ),
    (
      'hasProofOfResidentialAddress',
      'Proof of residential address',
      'Utility bill or tenancy agreement dated within 3 months.',
    ),
    (
      'hasTwoPassportPhotographs',
      'Two extra passport photographs',
      'Two further copies for your file.',
    ),
  ];

  /// The keys this step fills, so the wizard can require them before advancing.
  ///
  /// A getter rather than a `const` list: a collection-for over the records
  /// above trips the analyzer when used in a constant initializer.
  static List<String> get keys =>
      <String>[for (final (key, _, _) in documents) key];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Your documents',
          subtitle: 'Tell us which documents you can provide. You will bring '
              'the originals for verification before your vehicle is released.',
        ),
        for (final (key, title, hint) in documents)
          // A Material, not a Container: the card's ListTile paints its
          // background and splash on the nearest Material ancestor, and a
          // coloured DecoratedBox in between hides them.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE3E8E6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: YesNoGroup(
                  label: title,
                  hint: hint,
                  value: read(key) as bool?,
                  onChanged: (v) => write(key, v),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sections F and G — next of kin and two references.
class PeopleStep extends StatelessWidget {
  const PeopleStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  Map<String, dynamic> get _kin =>
      (read('nextOfKin') as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

  void _setKin(String key, String value) {
    final next = Map<String, dynamic>.from(_kin);
    next[key] = value;
    write('nextOfKin', next);
  }

  static const _referenceCount = 2;

  Map<String, dynamic> _reference(int index) {
    final list = read('references') as List? ?? const <dynamic>[];
    if (index < list.length && list[index] is Map) {
      return Map<String, dynamic>.from(list[index] as Map);
    }
    return <String, dynamic>{};
  }

  void _setReference(int index, String key, String value) {
    final next = List<Map<String, dynamic>>.generate(
      _referenceCount,
      (i) => i == index
          ? <String, dynamic>{..._reference(i), key: value}
          : _reference(i),
    );
    write('references', next);
  }

  @override
  Widget build(BuildContext context) {
    final kin = _kin;

    Widget reference(int index) {
      final reference = _reference(index);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FieldLabel(label: 'Reference ${index + 1}', required: true),
          TextFormField(
            initialValue: reference['fullName'] as String?,
            decoration: const InputDecoration(labelText: 'Full name *'),
            validator: (v) => requiredText(v),
            onChanged: (v) => _setReference(index, 'fullName', v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: reference['relationship'] as String?,
            decoration: const InputDecoration(labelText: 'Relationship *'),
            validator: (v) => requiredText(v),
            onChanged: (v) => _setReference(index, 'relationship', v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: reference['phoneNumber'] as String?,
            decoration: const InputDecoration(labelText: 'Phone number *'),
            keyboardType: TextInputType.phone,
            validator: phoneValidator,
            onChanged: (v) => _setReference(index, 'phoneNumber', v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: reference['address'] as String?,
            decoration: const InputDecoration(labelText: 'Address *'),
            validator: (v) => requiredText(v),
            onChanged: (v) => _setReference(index, 'address', v),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Next of kin & references',
          subtitle: 'The API requires exactly two references, so both are '
              'asked for here.',
        ),
        TextFormField(
          initialValue: kin['fullName'] as String?,
          decoration: const InputDecoration(labelText: 'Next of kin name *'),
          validator: (v) => requiredText(v),
          onChanged: (v) => _setKin('fullName', v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: kin['phoneNumber'] as String?,
          decoration: const InputDecoration(labelText: 'Next of kin phone *'),
          keyboardType: TextInputType.phone,
          validator: phoneValidator,
          onChanged: (v) => _setKin('phoneNumber', v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: kin['relationship'] as String?,
          decoration: const InputDecoration(labelText: 'Relationship *'),
          validator: (v) => requiredText(v),
          onChanged: (v) => _setKin('relationship', v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: kin['address'] as String?,
          decoration: const InputDecoration(labelText: 'Next of kin address *'),
          validator: (v) => requiredText(v),
          onChanged: (v) => _setKin('address', v),
        ),
        for (var i = 0; i < _referenceCount; i++) ...<Widget>[
          const SizedBox(height: 20),
          const Divider(height: 1),
          reference(i),
        ],
      ],
    );
  }
}

/// Section H — declaration only.
class FinalStep extends StatelessWidget {
  const FinalStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  static const declarationText =
      'I confirm the information I have provided is true and correct. '
      'I understand that approval is not automatic and I will complete '
      'verification before receiving my vehicle.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Declaration',
          subtitle: 'Please read and confirm.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TeamakColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E8E6)),
          ),
          child: const Text(
            declarationText,
            style: TextStyle(height: 1.5),
          ),
        ),
        CheckboxListTile(
          value: read('declarationAccepted') == true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: TeamakColors.primary,
          title: const Text('I accept and confirm my details are true.'),
          onChanged: (checked) => write('declarationAccepted', checked == true),
        ),
      ],
    );
  }
}
