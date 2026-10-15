import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../form/form_utils.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/shell.dart';
import '../receipt_page.dart' show statusLabel;

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({
    super.key,
    required this.api,
    required this.applicationId,
  });

  final ApiClient api;
  final String applicationId;

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  ApplicationDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // Section I controllers.
  final _receivedBy = TextEditingController();
  final _remark = TextEditingController();
  final _approvedAmount = TextEditingController();
  final _verificationDate = TextEditingController();
  final _deliveryDate = TextEditingController();
  String? _approvedProgramme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receivedBy.dispose();
    _remark.dispose();
    _approvedAmount.dispose();
    _verificationDate.dispose();
    _deliveryDate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.fetchApplication(widget.applicationId);
      final official = detail.official;
      if (mounted) {
        setState(() {
          _detail = detail;
          _receivedBy.text = '${official['receivedBy'] ?? ''}';
          _remark.text = '${official['remarks'] ?? ''}';
          _approvedAmount.text = official['approvedAmount'] == null
              ? ''
              : '${official['approvedAmount']}';
          _verificationDate.text = '${official['verificationDate'] ?? ''}';
          _deliveryDate.text = '${official['expectedDeliveryDate'] ?? ''}';
          _approvedProgramme = official['approvedProgrammeId']?.toString();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ApiClient get _api => widget.api;

  Future<void> _save(String status, {String? confirmMessage}) async {
    final detail = _detail;
    if (detail == null) return;

    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm decision'),
          content: Text(confirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _api.updateStatus(
        id: detail.id,
        status: status,
        remark: _remark.text,
        receivedBy: _receivedBy.text,
        verificationDate: _verificationDate.text,
        approvedProgrammeId: _approvedProgramme,
        approvedAmount: int.tryParse(_approvedAmount.text.replaceAll(',', '')),
        expectedDeliveryDate: _deliveryDate.text,
      );
      if (!mounted) return;
      setState(() => _detail = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status set to ${statusLabel(status)}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;

    return AppShell(
      title: 'Application review',
      child: _loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('$_error', style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => context.go('/staff'),
                          child: const Text('Back to dashboard'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildDetail(wide),
    );
  }

  Widget _buildDetail(bool wide) {
    final detail = _detail!;
    final application = detail.application;

    final content = <Widget>[
      _HeaderCard(detail: detail),
      const SizedBox(height: 16),
      _OfficialSection(
        detail: detail,
        receivedBy: _receivedBy,
        remark: _remark,
        approvedAmount: _approvedAmount,
        verificationDate: _verificationDate,
        deliveryDate: _deliveryDate,
        approvedProgramme: _approvedProgramme,
        onProgrammeChanged: (v) => setState(() => _approvedProgramme = v),
        saving: _saving,
        onDecided: _save,
        onPickDate: (controller, [first]) async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: first ?? DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (picked != null) controller.text = isoDate(picked);
        },
      ),
      const SizedBox(height: 16),
      _EventsCard(events: detail.events),
      const SizedBox(height: 16),
      _AnswersCard(application: application),
    ];

    return ListView(
      padding: EdgeInsets.all(wide ? 24 : 14),
      children: <Widget>[
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => context.go('/staff'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Dashboard'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(children: content),
              ),
            ],
          )
        else
          Column(children: content),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final ApplicationDetail detail;

  @override
  Widget build(BuildContext context) {
    final application = detail.application;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  detail.applicationNo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${application['fullName']}  •  ${application['phoneNumber']}',
                  style: const TextStyle(color: TeamakColors.subtle),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel(detail.status),
                style: const TextStyle(
                  color: TeamakColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialSection extends StatelessWidget {
  const _OfficialSection({
    required this.detail,
    required this.receivedBy,
    required this.remark,
    required this.approvedAmount,
    required this.verificationDate,
    required this.deliveryDate,
    required this.approvedProgramme,
    required this.onProgrammeChanged,
    required this.saving,
    required this.onDecided,
    required this.onPickDate,
  });

  final ApplicationDetail detail;
  final TextEditingController receivedBy;
  final TextEditingController remark;
  final TextEditingController approvedAmount;
  final TextEditingController verificationDate;
  final TextEditingController deliveryDate;
  final String? approvedProgramme;
  final ValueChanged<String?> onProgrammeChanged;
  final bool saving;
  final Future<void> Function(String status, {String? confirmMessage}) onDecided;
  final Future<void> Function(TextEditingController, [DateTime?]) onPickDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Section I — for official use only',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Verification, approval and delivery details.',
              style: TextStyle(color: TeamakColors.subtle),
            ),
            const SizedBox(height: 16),
            // Stacks on phones; two fields side by side at ~360px leaves each
            // one too narrow to read or type into.
            _FieldRow(
              children: <Widget>[
                TextField(
                  controller: receivedBy,
                  decoration: const InputDecoration(
                    labelText: 'Application received by',
                  ),
                ),
                TextField(
                  controller: verificationDate,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Verification date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: () => onPickDate(verificationDate),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FieldRow(
              children: <Widget>[
                DropdownButtonFormField<String?>(
                  initialValue: approvedProgramme,
                  decoration: const InputDecoration(
                    labelText: 'Approved programme',
                  ),
                  items: const <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— not set —'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'okada_650',
                      child: Text('Okada ₦650,000 / 3 months'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'okada_400',
                      child: Text('Okada ₦400,000 / 6 months'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'maruwa_2300',
                      child: Text('Maruwa ₦2,300,000 / 3 months'),
                    ),
                  ],
                  onChanged: saving ? null : onProgrammeChanged,
                ),
                TextField(
                  controller: approvedAmount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Approved amount (₦)'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FieldRow(
              children: <Widget>[
                TextField(
                  controller: deliveryDate,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Expected delivery / completion date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: () => onPickDate(deliveryDate, DateTime.now()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: remark,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () => onDecided(
                            'pending',
                            confirmMessage:
                                'Move this application to “under review”?',
                          ),
                  icon: const Icon(Icons.hourglass_top),
                  label: const Text('Send for review'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TeamakColors.primary,
                  ),
                  onPressed: saving
                      ? null
                      : () => onDecided(
                            'approved',
                            confirmMessage:
                                'Approve this application and record the '
                                'programme details?',
                          ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                  ),
                  onPressed: saving
                      ? null
                      : () => onDecided(
                            'further_review',
                            confirmMessage:
                                'Request further review of this application?',
                          ),
                  icon: const Icon(Icons.rule),
                  label: const Text('Further review'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: saving
                      ? null
                      : () => onDecided(
                            'not_approved',
                            confirmMessage:
                                'Mark this application as not approved?',
                          ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Not approved'),
                ),
                if (saving) const CircularProgressIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays out two form fields side by side on desktop and stacked on phones.
///
/// Stacking matters because two fields sharing a ~360px viewport leave each
/// one narrow enough to be awkward to read and type into.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < children.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
              child: children[i],
            ),
          ),
      ],
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final List<dynamic> events;

  /// Renders an ISO timestamp as `YYYY-MM-DD HH:MM`, tolerating short values.
  static String _stamp(Object? raw) {
    final text = '${raw ?? ''}'.replaceAll('T', ' ');
    return text.length >= 16 ? text.substring(0, 16) : text;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text(
                'No status changes yet.',
                style: TextStyle(color: TeamakColors.subtle),
              )
            else
              for (final raw in events)
                Builder(builder: (context) {
                  final event = Map<String, dynamic>.from(raw as Map);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.circle, size: 8, color: TeamakColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${statusLabel('${event['fromStatus']}')} → '
                            '${statusLabel('${event['toStatus']}')}'
                            '${event['remark'] == null ? '' : ' — ${event['remark']}'}',
                          ),
                        ),
                        // Guarded substring: an ISO timestamp is 20 chars, but
                        // a short or malformed value would otherwise throw a
                        // RangeError and blank the whole history card.
                        Text(
                          '${event['staffUsername'] ?? ''}  '
                          '${_stamp(event['createdAt'])}',
                          style: const TextStyle(
                            color: TeamakColors.subtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}

class _AnswersCard extends StatelessWidget {
  const _AnswersCard({required this.application});

  final Map<String, dynamic> application;

  static const groups = <MapEntry<String, List<MapEntry<String, String>>>>[
    MapEntry('Section A — applicant', <MapEntry<String, String>>[
      MapEntry('fullName', 'Full name'),
      MapEntry('phoneNumber', 'Phone'),
      MapEntry('whatsappNumber', 'WhatsApp'),
      MapEntry('residentialAddress', 'Address'),
      MapEntry('areaCommunity', 'Area / community'),
      MapEntry('dateOfBirth', 'Date of birth'),
      MapEntry('nin', 'NIN'),
      MapEntry('maritalStatus', 'Marital status'),
    ]),
    MapEntry('Section B — rider / operator', <MapEntry<String, String>>[
      MapEntry('operationType', 'Operation type'),
      MapEntry('ridingExperience', 'Experience'),
      MapEntry('currentVehicleOwnership', 'Current vehicle'),
      MapEntry('vehicleMakeModel', 'Make / model'),
      MapEntry('parkRouteOperatingArea', 'Park / route'),
      MapEntry('parkAssociationName', 'Association'),
      MapEntry('currentRemittance', 'Remittance'),
      MapEntry('averageWorkingDaysPerWeek', 'Working days / week'),
    ]),
    MapEntry('Section C — programme', <MapEntry<String, String>>[
      MapEntry('programmeId', 'Programme'),
    ]),
    MapEntry('Section D — funding', <MapEntry<String, String>>[
      MapEntry('amountToCommit', 'Amount to commit (₦)'),
      MapEntry('sourceOfFunds', 'Source of funds'),
      MapEntry('expectedDepositDate', 'Expected deposit date'),
      MapEntry('participatedBefore', 'Participated before'),
      MapEntry('previousProgrammeDetails', 'Previous programme'),
    ]),
    // The checklist the applicant answers in the wizard. A "No" here means the
    // rider will bring the originals later, not that the form was skipped.
    MapEntry('Section E — documents', <MapEntry<String, String>>[
      MapEntry('hasPassportPhotograph', 'Passport photograph'),
      MapEntry('hasGovernmentIdOrNinSlip', 'Government ID / NIN slip'),
      MapEntry('hasRiderOrAssociationRegistration', 'Rider registration'),
      MapEntry('hasProofOfResidentialAddress', 'Proof of address'),
      MapEntry('hasTwoPassportPhotographs', 'Two extra photographs'),
    ]),
    MapEntry('Section F — next of kin', <MapEntry<String, String>>[
      MapEntry('nextOfKin.fullName', 'Name'),
      MapEntry('nextOfKin.relationship', 'Relationship'),
      MapEntry('nextOfKin.phoneNumber', 'Phone'),
      MapEntry('nextOfKin.address', 'Address'),
    ]),
    MapEntry('Section G — references', <MapEntry<String, String>>[
      MapEntry('references.0', 'Reference 1'),
      MapEntry('references.1', 'Reference 2'),
    ]),
    MapEntry('Section H — declaration', <MapEntry<String, String>>[
      MapEntry('declarationAccepted', 'Declaration accepted'),
      MapEntry('signatureName', 'Signature'),
      MapEntry('declarationDate', 'Date'),
    ]),
  ];

  static Object? lookup(Map<String, dynamic> data, String path) {
    Object? current = data;
    for (final part in path.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  static String format(Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) {
      return value.isEmpty ? '—' : value.map((e) => '$e').join(', ');
    }
    if (value is Map) {
      return value.values.map((e) => '$e').join(' • ');
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Applicant answers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            for (final group in groups) ...<Widget>[
              Text(
                group.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TeamakColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TeamakColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (final field in group.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 170,
                              child: Text(
                                field.value,
                                style: const TextStyle(
                                  color: TeamakColors.subtle,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                format(lookup(application, field.key)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
