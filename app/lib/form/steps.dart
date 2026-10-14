import 'package:flutter/material.dart';

import '../theme.dart';
import 'form_utils.dart';

/// Signature for reading the in-progress application answers.
typedef DataReader = Object? Function(String key);

/// Signature for writing an answer (triggers a rebuild).
typedef DataWriter = void Function(String key, Object? value);

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: TeamakColors.subtle)),
          const SizedBox(height: 20),
        ],
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 14),
        child: Text(
          required ? '$label *' : label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
}

/// Radio-style option group used for the form's enumerated questions.
class OptionGroup extends StatelessWidget {
  const OptionGroup({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.columns = 2,
  });

  final String label;
  final String? value;
  final List<MapEntry<String, String>> options;
  final ValueChanged<String> onChanged;
  final bool required;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = columns > 1 ? width / columns : width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label: label, required: required),
        RadioGroup<String>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in options)
                SizedBox(
                  width: tileWidth,
                  child: RadioListTile<String>(
                    value: option.key,
                    title: Text(
                      option.value,
                      style: const TextStyle(fontSize: 14),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: TeamakColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section A — applicant information.
class AboutStep extends StatelessWidget {
  const AboutStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  @override
  Widget build(BuildContext context) {
    final dobText = read('dateOfBirth') as String?;
    DateTime? dob;
    if (dobText != null && dobText.isNotEmpty) dob = DateTime.tryParse(dobText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'About you',
          subtitle: 'Tell us who you are.',
        ),
        TextFormField(
          initialValue: read('fullName') as String?,
          decoration: const InputDecoration(labelText: 'Full name *'),
          textInputAction: TextInputAction.next,
          validator: fullNameValidator,
          onChanged: (v) => write('fullName', v),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: read('phoneNumber') as String?,
                decoration: const InputDecoration(labelText: 'Phone number *'),
                keyboardType: TextInputType.phone,
                validator: phoneValidator,
                onChanged: (v) {
                  write('phoneNumber', v);
                  if (read('whatsappNumber') == null) write('whatsappNumber', v);
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                initialValue: read('whatsappNumber') as String?,
                decoration: const InputDecoration(labelText: 'WhatsApp number'),
                keyboardType: TextInputType.phone,
                validator: optionalPhoneValidator,
                onChanged: (v) => write('whatsappNumber', v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: read('residentialAddress') as String?,
          decoration: const InputDecoration(labelText: 'Residential address *'),
          maxLines: 2,
          validator: (v) => requiredText(v),
          onChanged: (v) => write('residentialAddress', v),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: dobText,
                decoration: InputDecoration(
                  labelText: 'Date of birth *',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: () async {
                      final picked = await pickDate(context, initial: dob);
                      if (picked != null) write('dateOfBirth', isoDate(picked));
                    },
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Date of birth is required.';
                  return dateOfBirthValidator(DateTime.tryParse(v));
                },
                onChanged: (v) => write('dateOfBirth', v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                initialValue: read('nin') as String?,
                decoration: const InputDecoration(labelText: 'NIN *'),
                keyboardType: TextInputType.number,
                validator: ninValidator,
                onChanged: (v) => write('nin', v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section B — riding details.
class RidingStep extends StatelessWidget {
  const RidingStep({super.key, required this.read, required this.write});

  final DataReader read;
  final DataWriter write;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const StepHeader(
          title: 'Your riding business',
          subtitle: 'A few quick questions about your work.',
        ),
        OptionGroup(
          label: 'Type of operation',
          required: true,
          value: read('operationType') as String?,
          options: const <MapEntry<String, String>>[
            MapEntry('okada', 'Okada (motorcycle)'),
            MapEntry('maruwa', 'Maruwa (tricycle)'),
          ],
          onChanged: (v) => write('operationType', v),
        ),
        OptionGroup(
          label: 'Years of riding experience',
          required: true,
          value: read('ridingExperience') as String?,
          options: const <MapEntry<String, String>>[
            MapEntry('lt1', 'Less than 1 year'),
            MapEntry('y1_3', '1–3 years'),
            MapEntry('y4_6', '4–6 years'),
            MapEntry('y7_plus', '7+ years'),
          ],
          onChanged: (v) => write('ridingExperience', v),
          columns: 4,
        ),
        OptionGroup(
          label: 'Current vehicle',
          required: true,
          value: read('currentVehicleOwnership') as String?,
          options: const <MapEntry<String, String>>[
            MapEntry('owned', 'Owned by me'),
            MapEntry('rented', 'Rented'),
            MapEntry('none', 'None yet'),
          ],
          onChanged: (v) => write('currentVehicleOwnership', v),
          columns: 3,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: read('parkRouteOperatingArea') as String?,
          decoration: const InputDecoration(
            labelText: 'Park / route / operating area *',
          ),
          validator: (v) => requiredText(v),
          onChanged: (v) => write('parkRouteOperatingArea', v),
        ),
      ],
    );
  }
}
