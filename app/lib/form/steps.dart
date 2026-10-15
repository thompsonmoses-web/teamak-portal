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

class YesNoGroup extends StatelessWidget {
  const YesNoGroup({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.hint,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label: label, required: required),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              hint!,
              style: const TextStyle(color: TeamakColors.subtle, fontSize: 13),
            ),
          ),
        // Expanded rather than a fixed tile width: several of these sit inside
        // padded cards, so a half-screen tile would overflow them on a phone.
        RadioGroup<bool>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Row(
            children: <Widget>[
              Expanded(
                child: RadioListTile<bool>(
                  value: true,
                  title: const Text('Yes', style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: TeamakColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RadioListTile<bool>(
                  value: false,
                  title: const Text('No', style: TextStyle(fontSize: 14)),
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

/// Date input backed by a controller, so picking from the calendar updates the
/// visible text.
///
/// A `TextFormField(initialValue: ...)` would not: the field keeps its own
/// state across rebuilds, so the answer reaches the form map while the box
/// stays empty and the validator then rejects it.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.first,
    this.last,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final DateTime? first;
  final DateTime? last;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The calendar day [date] falls on.
  ///
  /// Bounds carry a time of day (they come from `DateTime.now()`) while a
  /// parsed form value carries none, so comparing them raw would reject
  /// "today" — a day the calendar itself offers as a valid choice.
  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime? get _firstBound =>
      widget.first == null ? null : _day(widget.first!);

  DateTime? get _lastBound => widget.last == null ? null : _day(widget.last!);

  Future<void> _pick() async {
    final picked = await pickDate(
      context,
      initial: DateTime.tryParse(widget.value ?? ''),
      first: _firstBound,
      last: _lastBound,
    );
    if (picked != null) widget.onChanged(isoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          onPressed: _pick,
        ),
      ),
      // Typing stays allowed: faster than the picker, and the only way to
      // enter a date in an automated test. The bounds double as validation,
      // reusing the same values the picker enforces.
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) {
          return '${widget.label.replaceAll(' *', '')} is required.';
        }
        final parsed = DateTime.tryParse(text);
        if (parsed == null) return 'Use the format YYYY-MM-DD.';
        final day = _day(parsed);
        final last = _lastBound;
        if (last != null && day.isAfter(last)) {
          return 'This date cannot be in the future.';
        }
        final first = _firstBound;
        if (first != null && day.isBefore(first)) {
          return 'This date must be on or after ${isoDate(first)}.';
        }
        return null;
      },
      onChanged: widget.onChanged,
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
        TextFormField(
          initialValue: read('areaCommunity') as String?,
          decoration: const InputDecoration(labelText: 'Area / community *'),
          validator: (v) => requiredText(v),
          onChanged: (v) => write('areaCommunity', v),
        ),
        const SizedBox(height: 14),
        OptionGroup(
          label: 'Marital status',
          required: true,
          value: read('maritalStatus') as String?,
          options: const <MapEntry<String, String>>[
            MapEntry('single', 'Single'),
            MapEntry('married', 'Married'),
            MapEntry('other', 'Other'),
          ],
          onChanged: (v) => write('maritalStatus', v),
        ),
        if (read('maritalStatus') == 'other') ...<Widget>[
          TextFormField(
            initialValue: read('maritalStatusOther') as String?,
            decoration: const InputDecoration(
              labelText: 'Please specify *',
            ),
            validator: (v) => requiredText(v),
            onChanged: (v) => write('maritalStatusOther', v),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: DateField(
                label: 'Date of birth *',
                value: dobText,
                onChanged: (v) => write('dateOfBirth', v),
                first: DateTime(1950),
                last: today,
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
          // These values mirror the API's enum; "None yet" is answered as
          // other with an explanation, since the API has no none value.
          options: const <MapEntry<String, String>>[
            MapEntry('owned', 'Owned by me'),
            MapEntry('rented', 'Rented'),
            MapEntry('hired_leased', 'Hired / leased'),
            MapEntry('other', 'Other (incl. none yet)'),
          ],
          onChanged: (v) => write('currentVehicleOwnership', v),
        ),
        if (read('currentVehicleOwnership') == 'other') ...<Widget>[
          TextFormField(
            initialValue: read('currentVehicleOther') as String?,
            decoration: const InputDecoration(
              labelText: 'Please specify *',
            ),
            validator: (v) => requiredText(v),
            onChanged: (v) => write('currentVehicleOther', v),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          initialValue: read('parkRouteOperatingArea') as String?,
          decoration: const InputDecoration(
            labelText: 'Park / route / operating area *',
          ),
          validator: (v) => requiredText(v),
          onChanged: (v) => write('parkRouteOperatingArea', v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: read('parkAssociationName') as String?,
          decoration: const InputDecoration(
            labelText: 'Park association name *',
          ),
          validator: (v) => requiredText(v),
          onChanged: (v) => write('parkAssociationName', v),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: read('currentRemittance') as String?,
                decoration: const InputDecoration(
                  labelText: 'Current daily remittance *',
                  hintText: 'e.g. 1,500 Naira daily',
                ),
                validator: (v) => requiredText(v, 'Remittance is required.'),
                onChanged: (v) => write('currentRemittance', v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                initialValue: read('averageWorkingDaysPerWeek')?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Working days per week *',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => integerValidator(
                  v,
                  message: 'Working days are required.',
                  min: 0,
                  max: 7,
                ),
                onChanged: (v) => write('averageWorkingDaysPerWeek', int.tryParse(v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
