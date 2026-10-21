import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// In-browser stand-in for the Teamak API.
///
/// The GitHub Pages build (`API_BASE=demo`) has no server behind it — Pages
/// hosts static files only — so this class answers the same URLs the real
/// Dart Frog API serves, backed by a JSON store in the browser's local
/// storage. It exists so the permanent pages link behaves like the real
/// portal: applying, tracking, staff review and team management all work,
/// within one browser.
///
/// Not for production: it is a preview. Passwords sit in plain text inside
/// the store and every visitor seeds their own copy; the banner in the app
/// chrome says so on every screen. The real deployment (local or tunnelled)
/// talks to the Dart Frog API and never loads this file's logic.
class DemoBackend {
  DemoBackend._();

  static const _prefsKey = 'teamak_demo_store';

  /// Answers one request exactly as the real API would: same URLs, same
  /// status codes, same JSON shapes, same error strings where the UI shows
  /// them.
  static Future<http.Response> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final store = await _load(prefs);
    final response = store.handle(method, path, query, body, token);
    // Persist after every answer, so a submission survives a reload the way
    // the real database would keep it.
    await prefs.setString(_prefsKey, jsonEncode(store.toJson()));
    return response;
  }

  static Future<_Store> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        return _Store.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt store is not worth rescuing in a preview: reseed.
      }
    }
    return _Store.seeded();
  }
}

/// The browser-side database: applications, messages, staff, live sessions.
class _Store {
  _Store({
    required this.applications,
    required this.messages,
    required this.staff,
    required this.tokens,
    required this.nextApplicationId,
    required this.nextMessageId,
    required this.nextStaffId,
  });

  factory _Store.fromJson(Map<String, dynamic> json) => _Store(
        applications: _maps(json['applications']),
        messages: _maps(json['messages']),
        staff: _maps(json['staff']),
        tokens: {
          for (final entry in (json['tokens'] as Map? ?? const {}).entries)
            '${entry.key}': (entry.value as num).toInt(),
        },
        nextApplicationId: (json['nextApplicationId'] as num?)?.toInt() ?? 1,
        nextMessageId: (json['nextMessageId'] as num?)?.toInt() ?? 1,
        nextStaffId: (json['nextStaffId'] as num?)?.toInt() ?? 1,
      );

  factory _Store.seeded() {
    final applications = <Map<String, dynamic>>[
      _seedApplication(
        id: 1,
        applicationNo: 'TRP-2026-0001',
        status: 'pending',
        programmeId: 'okada_650',
        createdAt: '2026-10-02T09:14:00Z',
        payload: <String, Object?>{
          'fullName': 'Adebayo Ogundele',
          'phoneNumber': '08023449126',
          'whatsappNumber': '08023449126',
          'residentialAddress': '12 Ojoo Road, Ibadan',
          'areaCommunity': 'Ojoo',
          'nin': '12345678901',
          'parkAssociationName': 'Ojoo Okada Park',
          'hasPassportPhotograph': true,
          'hasTwoPassportPhotographs': false,
          'hasGovernmentIdOrNinSlip': true,
          'hasRiderOrAssociationRegistration': true,
          'hasProofOfResidentialAddress': false,
        },
        events: <Map<String, Object?>>[
          <String, Object?>{
            'fromStatus': 'submitted',
            'toStatus': 'pending',
            'staffUsername': 'demo',
            'createdAt': '2026-10-02T15:30:00Z',
          },
        ],
      ),
      _seedApplication(
        id: 2,
        applicationNo: 'TRP-2026-0002',
        status: 'approved',
        programmeId: 'maruwa_2300',
        createdAt: '2026-09-20T10:02:00Z',
        payload: <String, Object?>{
          'fullName': 'Folake Adeyemi',
          'phoneNumber': '08031234567',
          'whatsappNumber': '08031234567',
          'residentialAddress': '5 Ring Road, Ibadan',
          'areaCommunity': 'Challenge',
          'nin': '87654321901',
          'parkAssociationName': 'Challenge Maruwa Park',
          'hasPassportPhotograph': true,
          'hasTwoPassportPhotographs': true,
          'hasGovernmentIdOrNinSlip': true,
          'hasRiderOrAssociationRegistration': true,
          'hasProofOfResidentialAddress': true,
        },
        official: <String, Object?>{
          'receivedBy': 'demo',
          'verificationStatus': 'verified',
          'verificationDate': '2026-10-08',
          'approvedProgrammeId': 'maruwa_2300',
          'approvedAmount': 2300000,
          'expectedDeliveryDate': '2026-12-15',
          'remarks': 'Verified at the park; originals sighted.',
          'updatedBy': 'demo',
        },
        events: <Map<String, Object?>>[
          <String, Object?>{
            'fromStatus': 'submitted',
            'toStatus': 'pending',
            'staffUsername': 'demo',
            'createdAt': '2026-09-20T14:00:00Z',
          },
          <String, Object?>{
            'fromStatus': 'pending',
            'toStatus': 'approved',
            'remark': 'Verified at the park; originals sighted.',
            'staffUsername': 'demo',
            'createdAt': '2026-10-08T11:20:00Z',
          },
        ],
      ),
      _seedApplication(
        id: 3,
        applicationNo: 'TRP-2026-0003',
        status: 'further_review',
        programmeId: 'okada_400',
        createdAt: '2026-10-06T08:40:00Z',
        payload: <String, Object?>{
          'fullName': 'Musa Ibrahim',
          'phoneNumber': '08059876543',
          'whatsappNumber': '08059876543',
          'residentialAddress': 'Bodija Estate, Ibadan',
          'areaCommunity': 'Bodija',
          'nin': '11223344556',
          'parkAssociationName': 'Bodija Okada Park',
          'hasPassportPhotograph': true,
          'hasTwoPassportPhotographs': true,
          'hasGovernmentIdOrNinSlip': false,
          'hasRiderOrAssociationRegistration': true,
          'hasProofOfResidentialAddress': true,
        },
        official: <String, Object?>{
          'receivedBy': 'demo',
          'remarks': 'Awaiting association confirmation letter.',
          'updatedBy': 'demo',
        },
        events: <Map<String, Object?>>[
          <String, Object?>{
            'fromStatus': 'submitted',
            'toStatus': 'pending',
            'staffUsername': 'demo',
            'createdAt': '2026-10-06T12:00:00Z',
          },
          <String, Object?>{
            'fromStatus': 'pending',
            'toStatus': 'further_review',
            'remark': 'Awaiting association confirmation letter.',
            'staffUsername': 'demo',
            'createdAt': '2026-10-09T09:15:00Z',
          },
        ],
      ),
      _seedApplication(
        id: 4,
        applicationNo: 'TRP-2026-0004',
        status: 'not_approved',
        programmeId: 'okada_650',
        createdAt: '2026-09-28T16:05:00Z',
        payload: <String, Object?>{
          'fullName': 'Grace Okafor',
          'phoneNumber': '08077778888',
          'whatsappNumber': '08077778888',
          'residentialAddress': '8 Dugbe Road, Ibadan',
          'areaCommunity': 'Dugbe',
          'nin': '99887766554',
          'parkAssociationName': 'Dugbe Okada Park',
          'hasPassportPhotograph': false,
          'hasTwoPassportPhotographs': false,
          'hasGovernmentIdOrNinSlip': true,
          'hasRiderOrAssociationRegistration': false,
          'hasProofOfResidentialAddress': false,
        },
        official: <String, Object?>{
          'receivedBy': 'demo',
          'remarks': 'Could not be reached for verification after two attempts.',
          'updatedBy': 'demo',
        },
        events: <Map<String, Object?>>[
          <String, Object?>{
            'fromStatus': 'submitted',
            'toStatus': 'pending',
            'staffUsername': 'demo',
            'createdAt': '2026-09-28T17:00:00Z',
          },
          <String, Object?>{
            'fromStatus': 'pending',
            'toStatus': 'not_approved',
            'remark': 'Could not be reached for verification after two attempts.',
            'staffUsername': 'demo',
            'createdAt': '2026-10-04T10:30:00Z',
          },
        ],
      ),
    ];

    return _Store(
      applications: applications,
      messages: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Chidi Okonkwo',
          'phone': '08031112222',
          'email': 'chidi@example.com',
          'subject': 'When is the next verification day?',
          'message': 'Please, I want to know the date for the Ojoo park '
              'verification visit.',
          'createdAt': '2026-10-10T09:00:00Z',
        },
        <String, dynamic>{
          'id': 2,
          'name': 'Aisha Bello',
          'phone': '08065554444',
          'email': '',
          'subject': 'Maruwa programme question',
          'message': 'Can I join the Maruwa plan with a partner?',
          'createdAt': '2026-10-11T14:25:00Z',
        },
      ],
      staff: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'username': 'admin',
          'fullName': 'Teamak Admin',
          'role': 'admin',
          'createdAt': '2026-09-01T08:00:00Z',
          'password': 'admin123',
        },
        <String, dynamic>{
          'id': 2,
          'username': 'demo',
          'fullName': 'Demo User',
          'role': 'admin',
          'createdAt': '2026-09-15T09:00:00Z',
          'password': 'demo1234',
        },
        <String, dynamic>{
          'id': 3,
          'username': 'reviewer',
          'fullName': 'Temi Reviewer',
          'role': 'reviewer',
          'createdAt': '2026-10-01T12:00:00Z',
          'password': 'reviewer1',
        },
      ],
      tokens: <String, int>{},
      nextApplicationId: 5,
      nextMessageId: 3,
      nextStaffId: 4,
    );
  }

  /// Full-detail records, oldest first.
  final List<Map<String, dynamic>> applications;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> staff;

  /// Live session tokens mapped to the staff id holding them.
  final Map<String, int> tokens;

  int nextApplicationId;
  int nextMessageId;
  int nextStaffId;

  Map<String, Object?> toJson() => <String, Object?>{
        'applications': applications,
        'messages': messages,
        'staff': staff,
        'tokens': tokens,
        'nextApplicationId': nextApplicationId,
        'nextMessageId': nextMessageId,
        'nextStaffId': nextStaffId,
      };

  // ── Dispatch ───────────────────────────────────────────────────────────

  http.Response handle(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
    String? token,
  ) {
    final params = query ?? const <String, String>{};
    final data =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

    if (path == '/programmes' && method == 'GET') {
      return _ok(<String, Object?>{
        'programmes': _programmes,
        'depositNote': _depositNote,
      });
    }
    if (path == '/auth/login' && method == 'POST') return _login(data);
    if (path == '/auth/logout' && method == 'POST') {
      if (token != null) tokens.remove(token);
      return _ok(<String, Object?>{});
    }
    if (path == '/auth/me' && method == 'GET') return _me(token);
    if (path == '/applications' && method == 'POST') return _create(data);
    if (path == '/applications' && method == 'GET') {
      return _list(params, token);
    }
    if (path == '/track' && method == 'POST') return _track(data);
    if (path == '/contact' && method == 'POST') return _contact(data);
    if (path == '/contact' && method == 'GET') return _messages(token);
    if (path == '/staff' && method == 'GET') return _staffList(token);
    if (path == '/staff' && method == 'POST') return _staffCreate(token, data);

    final staffUpdate = _staffPath.firstMatch(path);
    if (staffUpdate != null && method == 'PATCH') {
      return _staffUpdate(token, int.parse(staffUpdate.group(1)!), data);
    }
    final status = _statusPath.firstMatch(path);
    if (status != null && method == 'PATCH') {
      return _setStatus(token, status.group(1)!, data);
    }
    final application = _applicationPath.firstMatch(path);
    if (application != null && method == 'GET') {
      return _detail(token, application.group(1)!);
    }
    return _error(404, 'Resource not found.');
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  http.Response _login(Map<String, dynamic> data) {
    final username = '${data['username'] ?? ''}'.trim();
    final password = '${data['password'] ?? ''}';
    for (final account in staff) {
      if (account['username'] == username && account['password'] == password) {
        final token = 'demo-${DateTime.now().microsecondsSinceEpoch}-'
            '${Random.secure().nextInt(1 << 30)}';
        tokens[token] = account['id'] as int;
        return _ok(<String, Object?>{
          'token': token,
          'staff': _staffSummary(account),
        });
      }
    }
    return _error(401, 'Invalid username or password.');
  }

  http.Response _me(String? token) {
    final account = _staffFor(token);
    if (account == null) return _error(401, 'Authentication required.');
    return _ok(_staffSummary(account));
  }

  Map<String, dynamic>? _staffFor(String? token) {
    if (token == null) return null;
    final id = tokens[token];
    if (id == null) return null;
    for (final account in staff) {
      if (account['id'] == id) return account;
    }
    return null;
  }

  /// 401/403 for non-staff and non-admins, or null when the caller may
  /// proceed — exactly the wall the real API puts up.
  http.Response? _adminGuard(String? token) {
    final account = _staffFor(token);
    if (account == null) return _error(401, 'Authentication required.');
    if (account['role'] != 'admin') {
      return _error(403, 'Administrator access required.');
    }
    return null;
  }

  http.Response? _staffGuard(String? token) {
    final account = _staffFor(token);
    if (account == null) return _error(401, 'Authentication required.');
    return null;
  }

  // ── Applications ───────────────────────────────────────────────────────

  http.Response _create(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = nextApplicationId++;
    final record = <String, dynamic>{
      'id': '$id',
      'applicationNo': 'TRP-2026-${id.toString().padLeft(4, '0')}',
      'status': 'submitted',
      'programmeId': '${data['programmeId'] ?? 'okada_650'}',
      'createdAt': now,
      'updatedAt': now,
      'application': data,
      'official': <String, dynamic>{},
      'events': <dynamic>[],
    };
    applications.add(record);
    return _created(_full(record));
  }

  http.Response _list(Map<String, String> params, String? token) {
    final guard = _staffGuard(token);
    if (guard != null) return guard;

    final status = params['status'] ?? '';
    if (status.isNotEmpty && !_statuses.contains(status)) {
      return _error(400, 'Unknown status: $status');
    }
    final query = (params['q'] ?? '').trim().toLowerCase();
    final limit = int.tryParse(params['limit'] ?? '') ?? 100;

    bool matches(Map<String, dynamic> record) {
      if (status.isNotEmpty && record['status'] != status) return false;
      if (query.isEmpty) return true;
      final payload = _payload(record);
      final haystack = '${record['applicationNo']} '
              '${payload['fullName'] ?? ''} ${payload['phoneNumber'] ?? ''}'
          .toLowerCase();
      return haystack.contains(query);
    }

    final filtered = applications.reversed.where(matches).toList();
    return _ok(<String, Object?>{
      'total': filtered.length,
      'results': filtered.take(limit).map(_summary).toList(),
      'counts': _counts(),
    });
  }

  http.Response _detail(String? token, String id) {
    final guard = _staffGuard(token);
    if (guard != null) return guard;
    final record = _find(id);
    if (record == null) return _error(404, 'Application not found.');
    return _ok(_full(record));
  }

  http.Response _setStatus(
    String? token,
    String id,
    Map<String, dynamic> data,
  ) {
    final guard = _staffGuard(token);
    if (guard != null) return guard;
    final account = _staffFor(token)!;
    final record = _find(id);
    if (record == null) return _error(404, 'Application not found.');

    final status = '${data['status'] ?? ''}';
    if (!_staffSettable.contains(status)) {
      return _error(400, 'Choose a valid status.', errors: <String, String>{
        'status': 'Not a reviewable status.',
      });
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final previous = '${record['status']}';
    record['status'] = status;
    record['updatedAt'] = now;

    // Mutate the record's own map — _official() hands back a copy, which is
    // right for reads and wrong here, where the decision must stick.
    final storedOfficial = record['official'];
    final official = storedOfficial is Map<String, dynamic>
        ? storedOfficial
        : Map<String, dynamic>.from(storedOfficial as Map? ?? const {});
    record['official'] = official;
    for (final key in const <String>[
      'receivedBy',
      'verificationStatus',
      'verificationDate',
      'approvedProgrammeId',
      'approvedAmount',
      'expectedDeliveryDate',
    ]) {
      if (data.containsKey(key)) official[key] = data[key];
    }
    if (data['remark'] != null) official['remarks'] = data['remark'];
    official['updatedBy'] = account['username'];

    (record['events'] as List<dynamic>).add(<String, Object?>{
      'fromStatus': previous,
      'toStatus': status,
      if (data['remark'] != null) 'remark': data['remark'],
      'staffUsername': account['username'],
      'createdAt': now,
    });
    return _ok(_full(record));
  }

  http.Response _track(Map<String, dynamic> data) {
    final applicationNo = '${data['applicationNo'] ?? ''}'.trim();
    final phone = _normalisePhone('${data['phone'] ?? ''}');
    for (final record in applications.reversed) {
      if ('${record['applicationNo']}' != applicationNo) continue;
      final payload = _payload(record);
      if (_normalisePhone('${payload['phoneNumber'] ?? ''}') != phone) {
        continue;
      }
      final public = _full(record);
      // Staff-only Section I stays staff-only, exactly like the real /track.
      final official = Map<String, dynamic>.from(public['official'] as Map);
      official.remove('receivedBy');
      official.remove('remarks');
      official.remove('updatedBy');
      public['official'] = official;
      return _ok(public);
    }
    return _error(404, 'No application matches that number and phone number.');
  }

  Map<String, dynamic>? _find(String id) {
    for (final record in applications) {
      if ('${record['id']}' == id) return record;
    }
    return null;
  }

  Map<String, Object?> _counts() {
    final counts = <String, int>{
      'total': applications.length,
      for (final status in _statuses) status: 0,
    };
    for (final record in applications) {
      final status = '${record['status']}';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  // ── Contact ────────────────────────────────────────────────────────────

  http.Response _contact(Map<String, dynamic> data) {
    final name = '${data['name'] ?? ''}'.trim();
    final phone = '${data['phone'] ?? ''}'.trim();
    final message = '${data['message'] ?? ''}'.trim();
    if (name.isEmpty || phone.isEmpty || message.isEmpty) {
      return _error(400, 'Name, phone and message are required.', errors: {
        if (name.isEmpty) 'name': 'Required.',
        if (phone.isEmpty) 'phone': 'Required.',
        if (message.isEmpty) 'message': 'Required.',
      });
    }
    messages.insert(0, <String, dynamic>{
      'id': nextMessageId++,
      'name': name,
      'phone': phone,
      'email': '${data['email'] ?? ''}'.trim(),
      'subject': '${data['subject'] ?? 'General enquiry'}'.trim(),
      'message': message,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    return _ok(<String, Object?>{
      'message': 'Thank you, $name! Your message has been received. '
          'Our team will get back to you on $phone.',
    });
  }

  http.Response _messages(String? token) {
    final guard = _staffGuard(token);
    if (guard != null) return guard;
    return _ok(<String, Object?>{'messages': messages});
  }

  // ── Staff directory ────────────────────────────────────────────────────

  http.Response _staffList(String? token) {
    final guard = _adminGuard(token);
    if (guard != null) return guard;
    return _ok(<String, Object?>{
      'items': staff.map(_staffSummary).toList(),
    });
  }

  http.Response _staffCreate(String? token, Map<String, dynamic> data) {
    final guard = _adminGuard(token);
    if (guard != null) return guard;

    final username = '${data['username'] ?? ''}'.trim();
    final fullName = '${data['fullName'] ?? ''}'.trim();
    final password = '${data['password'] ?? ''}';
    final role = '${data['role'] ?? 'reviewer'}'.trim();

    final errors = <String, String>{};
    if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(username)) {
      errors['username'] =
          'Use 3–32 letters, numbers, dots, dashes or underscores.';
    }
    if (fullName.isEmpty) errors['fullName'] = 'Full name is required.';
    if (password.length < 6) errors['password'] = 'Use at least 6 characters.';
    if (!_roles.contains(role)) errors['role'] = 'Choose admin or reviewer.';
    if (errors.isNotEmpty) {
      return _error(400, 'Check the highlighted fields.', errors: errors);
    }
    if (staff.any((account) => account['username'] == username)) {
      return _error(409, 'That username is already taken.',
          errors: <String, String>{'username': 'Already taken.'});
    }

    final account = <String, dynamic>{
      'id': nextStaffId++,
      'username': username,
      'fullName': fullName,
      'role': role,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'password': password,
    };
    staff.add(account);
    return _created(_staffSummary(account));
  }

  http.Response _staffUpdate(
    String? token,
    int id,
    Map<String, dynamic> data,
  ) {
    final guard = _adminGuard(token);
    if (guard != null) return guard;

    Map<String, dynamic>? account;
    for (final candidate in staff) {
      if (candidate['id'] == id) {
        account = candidate;
        break;
      }
    }
    if (account == null) return _error(404, 'Staff member not found.');

    final fullName =
        data['fullName'] == null ? null : '${data['fullName']}'.trim();
    final role = data['role'] == null ? null : '${data['role']}'.trim();
    final password =
        data['password'] == null ? null : '${data['password']}';
    if (fullName == null && role == null && password == null) {
      return _error(400, 'Nothing to update.');
    }

    final errors = <String, String>{};
    if (fullName != null && fullName.isEmpty) {
      errors['fullName'] = 'Full name cannot be empty.';
    }
    if (role != null && !_roles.contains(role)) {
      errors['role'] = 'Choose admin or reviewer.';
    }
    if (password != null && password.length < 6) {
      errors['password'] = 'Use at least 6 characters.';
    }
    if (errors.isNotEmpty) {
      return _error(400, 'Check the highlighted fields.', errors: errors);
    }

    // Never let the last administrator drop their own rights — the real API
    // refuses this, and the preview should misbehave the same way.
    if (role != null &&
        role != 'admin' &&
        account['role'] == 'admin' &&
        staff.where((member) => member['role'] == 'admin').length <= 1) {
      return _error(400, 'At least one administrator must remain.',
          errors: <String, String>{
            'role': 'The last administrator cannot be demoted.',
          });
    }

    if (fullName != null) account['fullName'] = fullName;
    if (role != null) account['role'] = role;
    if (password != null) {
      account['password'] = password;
      // A password reset ends that account's sessions, on the spot.
      tokens.removeWhere((_, holder) => holder == id);
    }
    return _ok(_staffSummary(account));
  }

  // ── Shaping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _payload(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record['application'] as Map? ?? const {});

  Map<String, dynamic> _official(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record['official'] as Map? ?? const {});

  Map<String, Object?> _full(Map<String, dynamic> record) => <String, Object?>{
        ...record,
        'documents': <dynamic>[],
      };

  Map<String, Object?> _summary(Map<String, dynamic> record) {
    final payload = _payload(record);
    final official = _official(record);
    return <String, Object?>{
      'id': record['id'],
      'applicationNo': record['applicationNo'],
      'status': record['status'],
      'programmeId': record['programmeId'],
      'fullName': payload['fullName'] ?? '',
      'phoneNumber': payload['phoneNumber'] ?? '',
      'areaCommunity': payload['areaCommunity'] ?? '',
      'createdAt': record['createdAt'],
      'updatedAt': record['updatedAt'],
      'official': <String, Object?>{
        'verificationStatus': official['verificationStatus'],
        'approvedAmount': official['approvedAmount'],
        'expectedDeliveryDate': official['expectedDeliveryDate'],
      },
    };
  }

  Map<String, Object?> _staffSummary(Map<String, dynamic> account) =>
      <String, Object?>{
        'id': account['id'],
        'username': account['username'],
        'fullName': account['fullName'],
        'role': account['role'],
        'createdAt': account['createdAt'],
      };

  String _normalisePhone(String raw) {
    var digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length > 10 && digits.startsWith('234')) {
      digits = '0${digits.substring(3)}';
    }
    return digits;
  }

  static Map<String, dynamic> _seedApplication({
    required int id,
    required String applicationNo,
    required String status,
    required String programmeId,
    required String createdAt,
    required Map<String, Object?> payload,
    Map<String, Object?> official = const <String, Object?>{},
    List<Map<String, Object?>> events = const <Map<String, Object?>>[],
  }) =>
      <String, dynamic>{
        'id': '$id',
        'applicationNo': applicationNo,
        'status': status,
        'programmeId': programmeId,
        'createdAt': createdAt,
        'updatedAt': createdAt,
        'application': payload,
        'official': official,
        'events': events,
      };
}

List<Map<String, dynamic>> _maps(Object? value) => ((value as List?) ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();

final RegExp _staffPath = RegExp(r'^/staff/(\d+)$');
final RegExp _statusPath = RegExp(r'^/applications/([^/]+)/status$');
final RegExp _applicationPath = RegExp(r'^/applications/([^/]+)$');

http.Response _ok(Object body) => _json(body, 200);

http.Response _created(Object body) => _json(body, 201);

http.Response _error(
  int status,
  String message, {
  Map<String, String>? errors,
}) {
  final body = <String, Object?>{'error': message};
  if (errors != null) body['errors'] = errors;
  return _json(body, status);
}

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

/// Mirrors `server/lib/programmes.dart` — the preview must quote the same
/// tiers as the real thing.
const List<Map<String, Object>> _programmes = <Map<String, Object>>[
  <String, Object>{
    'id': 'okada_650',
    'label': 'OKADA OWNERSHIP',
    'depositNgn': 650000,
    'months': 3,
    'asset': '1 brand-new Bajaj motorcycle',
    'summary': '₦650,000 one-time deposit → 3 months → 1 brand-new Bajaj '
        'motorcycle.',
  },
  <String, Object>{
    'id': 'okada_400',
    'label': 'OKADA OWNERSHIP',
    'depositNgn': 400000,
    'months': 6,
    'asset': '1 brand-new Bajaj motorcycle',
    'summary': '₦400,000 one-time deposit → 6 months → 1 brand-new Bajaj '
        'motorcycle.',
  },
  <String, Object>{
    'id': 'maruwa_2300',
    'label': 'MARUWA OWNERSHIP',
    'depositNgn': 2300000,
    'months': 3,
    'asset': '1 Bajaj/approved Maruwa tricycle',
    'summary': '₦2,300,000 one-time deposit → 3 months → 1 Bajaj/approved '
        'Maruwa tricycle.',
  },
];

const String _depositNote =
    'The programme contribution is a one-time deposit under the selected '
    'option. There is no further vehicle payment under the stated ownership '
    'offer, subject to programme approval, verification and the applicable '
    'terms of the final agreement.';

const Set<String> _statuses = <String>{
  'submitted',
  'pending',
  'approved',
  'not_approved',
  'further_review',
};

const Set<String> _staffSettable = <String>{
  'pending',
  'approved',
  'not_approved',
  'further_review',
};

const Set<String> _roles = <String>{'admin', 'reviewer'};
