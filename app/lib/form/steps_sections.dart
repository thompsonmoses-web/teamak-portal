import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'form_utils.dart';
import 'steps.dart';

/// Section C — programme selection + next of kin + declaration.
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

  Map<String, dynamic> get _kin =>
      (read('nextOfKin') as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

  void _setKin(String key, String value) {
    final next = Map<String, dynamic>.from(_kin);
    next[key] = value;
    write('nextOfKin', next);
  }

  @override
  Widget build(BuildContext context) {
    final selected = read('programmeId') as String?;
    final kin = _kin;

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
        const SizedBox(height: 10),
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
      ],
    );
  }
}

/// Section D — declaration only.
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
