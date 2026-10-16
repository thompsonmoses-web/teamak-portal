import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../form/steps.dart';
import '../form/steps_sections.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/shell.dart';

class ApplyPage extends StatefulWidget {
  const ApplyPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  static const stepTitles = <String>[
    'About you',
    'Riding details',
    'Programme',
    'Funding',
    'Documents',
    'Next of kin & references',
    'Declaration',
  ];

  final Map<String, dynamic> _data = <String, dynamic>{};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _step = 0;
  bool _submitting = false;
  List<Programme> _programmes = const <Programme>[];
  String? _serverSummary;
  Map<String, String> _serverErrors = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadProgrammes();
  }

  Future<void> _loadProgrammes() async {
    try {
      final programmes = await widget.api.fetchProgrammes();
      if (mounted) setState(() => _programmes = programmes);
    } catch (_) {
      // Keep the fallback list below.
    }
  }

  List<Programme> get _tierOptions => _programmes.isNotEmpty
      ? _programmes
      : const <Programme>[
          Programme(
            id: 'okada_650',
            label: 'OKADA OWNERSHIP',
            depositNgn: 650000,
            months: 3,
            asset: '1 brand-new Bajaj motorcycle',
            summary: '₦650,000 one-time deposit → 3 months → brand-new Bajaj.',
          ),
          Programme(
            id: 'okada_400',
            label: 'OKADA OWNERSHIP',
            depositNgn: 400000,
            months: 6,
            asset: '1 brand-new Bajaj motorcycle',
            summary: '₦400,000 one-time deposit → 6 months → brand-new Bajaj.',
          ),
          Programme(
            id: 'maruwa_2300',
            label: 'MARUWA OWNERSHIP',
            depositNgn: 2300000,
            months: 3,
            asset: '1 Bajaj/approved Maruwa tricycle',
            summary: '₦2,300,000 one-time deposit → 3 months → approved Maruwa.',
          ),
        ];

  Object? _read(String key) => _data[key];

  void _write(String key, Object? value) {
    setState(() {
      _data[key] = value;
      // Auto-calculate age from date of birth.
      if (key == 'dateOfBirth' && value is String && value.isNotEmpty) {
        final dob = DateTime.tryParse(value);
        if (dob != null) {
          final now = DateTime.now();
          var age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          _data['age'] = '$age';
        }
      }
      // Auto-fill WhatsApp with phone if empty.
      if (key == 'phoneNumber' && _data['whatsappNumber'] == null) {
        _data['whatsappNumber'] = value;
      }
      // Auto-fill signature with full name.
      if (key == 'fullName' && _data['signatureName'] == null) {
        _data['signatureName'] = value;
      }
      // Auto-set declaration date when accepted.
      if (key == 'declarationAccepted' && value == true) {
        final now = DateTime.now();
        _data['declarationDate'] =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
      }
      // Auto-fill deposit amount from the selected programme. This refreshes
      // on every change: guarding on a null amount would leave the first
      // choice's figure in place if the applicant changed programme later.
      if (key == 'programmeId') {
        for (final programme in _tierOptions) {
          if (programme.id == value) {
            _data['amountToCommit'] = '${programme.depositNgn}';
          }
        }
      }
      _serverErrors = const <String, String>{};
    });
  }

  /// Fills anything the applicant skipped with a clearly-fake placeholder, so
  /// a visitor can walk the whole wizard by pressing Continue alone and still
  /// reach a real receipt. Values the applicant actually typed are kept.
  ///
  /// The placeholders satisfy the API's validator (two-word name, Nigerian
  /// phone shape, 11-digit NIN, an 18+ birth date, exactly two references).
  void _fillDemoDefaults() {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    void put(String key, Object? value) {
      final current = _data[key];
      final missing = current == null ||
          (current is String && current.trim().isEmpty) ||
          (current is List && current.isEmpty);
      if (missing) {
        _data[key] = value;
      }
    }

    final today = DateTime.now();
    final tier = _tierOptions.isEmpty ? null : _tierOptions.first;

    put('fullName', 'Demo Applicant');
    put('phoneNumber', '08000000000');
    put('whatsappNumber', '08000000000');
    put('residentialAddress', '1 Demo Street, Ibadan');
    put('areaCommunity', 'Demo Area, Ibadan');
    put('dateOfBirth', '1995-01-01');
    put('nin', '00000000000');
    put('maritalStatus', 'single');
    put('operationType', 'okada');
    put('ridingExperience', 'y1_3');
    put('currentVehicleOwnership', 'rented');
    put('parkRouteOperatingArea', 'Demo Park Route');
    put('parkAssociationName', 'Demo Park Association');
    put('currentRemittance', '₦1,500 daily');
    put('averageWorkingDaysPerWeek', 6);
    put('programmeId', tier?.id ?? 'okada_400');
    put('amountToCommit', tier?.depositNgn ?? 400000);
    put('sourceOfFunds', <String>['personal_savings']);
    put('expectedDepositDate', iso(today));
    put('participatedBefore', false);
    for (final key in const <String>[
      'hasPassportPhotograph',
      'hasGovernmentIdOrNinSlip',
      'hasRiderOrAssociationRegistration',
      'hasProofOfResidentialAddress',
      'hasTwoPassportPhotographs',
    ]) {
      put(key, true);
    }

    // Sections F and G hold nested maps/lists; merge so typed values win.
    final kin = <String, dynamic>{
      'fullName': 'Demo Kin',
      'relationship': 'Sibling',
      'phoneNumber': '08000000001',
      'address': '1 Demo Street, Ibadan',
      if (_data['nextOfKin'] is Map)
        ...Map<String, dynamic>.from(_data['nextOfKin']! as Map),
    };
    _data['nextOfKin'] = kin;

    final refs = <Map<String, dynamic>>[
      if (_data['references'] is List)
        for (final item in (_data['references']! as List))
          if (item is Map) Map<String, dynamic>.from(item),
    ];
    while (refs.length < 2) {
      refs.add(<String, dynamic>{
        'fullName': 'Demo Reference ${refs.length + 1}',
        'relationship': 'Colleague',
        'phoneNumber': '0800000000${refs.length + 2}',
        'address': '1 Demo Street, Ibadan',
      });
    }
    _data['references'] = refs;

    put('declarationAccepted', true);
    put('signatureName', 'Demo Applicant');
    put('declarationDate', iso(today));
  }

  void _next() {
    // No gate: the wizard is walk-through for demos, so Continue always
    // advances. Anything skipped is filled at submit time.
    setState(() {
      _step++;
      _serverSummary = null;
      _serverErrors = const <String, String>{};
    });
  }

  void _back() {
    setState(() {
      _step--;
      _serverSummary = null;
      _serverErrors = const <String, String>{};
    });
  }

  Future<void> _submit() async {
    _fillDemoDefaults();

    setState(() {
      _submitting = true;
      _serverSummary = null;
      _serverErrors = const <String, String>{};
    });

    try {
      final detail = await widget.api.submitApplication(Map<String, dynamic>.from(_data));
      if (!mounted) return;
      context.go('/dashboard', extra: detail);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverSummary = error.errors.isEmpty
            ? error.message
            : 'Please correct the highlighted fields.';
        _serverErrors = error.errors;
      });
    }
  }

  Widget _stepContent() {
    final read = _read;
    final write = _write;

    return switch (_step) {
      0 => AboutStep(read: read, write: write),
      1 => RidingStep(read: read, write: write),
      2 => ProgrammeStep(
          read: read,
          write: write,
          programmes: _tierOptions,
        ),
      3 => FundingStep(read: read, write: write),
      4 => DocumentsStep(read: read, write: write),
      5 => PeopleStep(read: read, write: write),
      _ => FinalStep(read: read, write: write),
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    final isLast = _step == stepTitles.length - 1;

    return AppShell(
      title: 'Application form',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: EdgeInsets.all(wide ? 28 : 16),
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TeamakColors.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'STEP ${_step + 1} OF ${stepTitles.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stepTitles[_step],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '${((_step + 1) / stepTitles.length * 100).round()}%',
                        style: const TextStyle(
                          color: TeamakColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / stepTitles.length,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE4E9F2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        TeamakColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_serverSummary != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _serverSummary!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final entry in _serverErrors.entries)
                        Text(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              Card(
                child: Padding(
                  padding: EdgeInsets.all(wide ? 26 : 18),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: _stepContent(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // A Wrap rather than a Row with a Spacer: at 320px the two
              // buttons need 328px of the 288px available, and stacking them
              // keeps both reachable instead of clipping one.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  if (_step > 0)
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _back,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  if (!isLast)
                    FilledButton.icon(
                      onPressed: _submitting ? null : _next,
                      label: const Text('Continue'),
                      icon: const Icon(Icons.arrow_forward),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_submitting ? 'Submitting…' : 'Submit'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: you can walk through by pressing Continue — anything you '
                'skip is filled with demo details before submitting.',
                style: TextStyle(color: TeamakColors.subtle, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
