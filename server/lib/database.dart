import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:sqlite3/sqlite3.dart';

import 'programmes.dart';

/// Thrown when a request cannot be satisfied because of state in the database.
class DatabaseException implements Exception {
  DatabaseException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _schema = '''
CREATE TABLE IF NOT EXISTS counters (
  name TEXT PRIMARY KEY,
  value INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS applications (
  id TEXT PRIMARY KEY,
  application_no TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'submitted',
  programme_id TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  nin TEXT NOT NULL,
  area_community TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS application_official (
  application_id TEXT PRIMARY KEY REFERENCES applications(id) ON DELETE CASCADE,
  received_by TEXT,
  verification_status TEXT NOT NULL DEFAULT 'pending',
  verification_date TEXT,
  approved_programme_id TEXT,
  approved_amount INTEGER,
  expected_delivery_date TEXT,
  remarks TEXT,
  updated_by TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS application_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  application_id TEXT NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  remark TEXT,
  staff_username TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS contact_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staff_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'reviewer',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  staff_id INTEGER NOT NULL REFERENCES staff_users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  application_id TEXT NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  file_name TEXT NOT NULL,
  stored_path TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_applications_created ON applications(created_at);
''';

/// Owns the SQLite connection and all persistence operations.
class TeamakDatabase {
  TeamakDatabase._(this._db);

  final Database _db;

  static TeamakDatabase? _instance;

  /// Process-wide instance. Path comes from `TEAMAK_DB`, defaulting to
  /// `teamak.db` next to the server working directory.
  static TeamakDatabase get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final path = Platform.environment['TEAMAK_DB'] ?? 'teamak.db';
    final opened = open(path);
    _instance = opened;
    return opened;
  }

  /// Opens a database at [path] and applies migrations. Use `:memory:` in tests.
  static TeamakDatabase open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON;');
    final database = TeamakDatabase._(db);
    database._migrate();
    database._seed();
    return database;
  }

  void _migrate() => _db.execute(_schema);

  void _seed() {
    final row = _db.select('SELECT COUNT(*) AS n FROM staff_users').first;
    if ((row['n'] as int) > 0) return;
    final username = Platform.environment['TEAMAK_ADMIN_USER'] ?? 'admin';
    final password = Platform.environment['TEAMAK_ADMIN_PASSWORD'] ?? 'admin123';
    createStaff(
      username: username,
      passwordHash: BCrypt.hashpw(password, BCrypt.gensalt()),
      fullName: 'Programme Administrator',
      role: 'admin',
    );
  }

  void dispose() => _db.dispose();

  // ── Applications ────────────────────────────────────────────────────────

  /// Atomically reserves the next application sequence number.
  int nextApplicationSequence() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO counters (name, value) VALUES (?, 0) '
        'ON CONFLICT(name) DO NOTHING',
        <Object?>['application'],
      );
      final row = _db.select(
        'SELECT value FROM counters WHERE name = ?',
        <Object?>['application'],
      );
      final next = (row.first['value'] as int) + 1;
      _db.execute(
        'UPDATE counters SET value = ? WHERE name = ?',
        <Object?>[next, 'application'],
      );
      _db.execute('COMMIT');
      return next;
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static String formatApplicationNumber(int sequence, {int? year}) {
    final y = year ?? DateTime.now().toUtc().year;
    return 'TRP-$y-${sequence.toString().padLeft(4, '0')}';
  }

  Map<String, Object?> insertApplication({
    required Map<String, dynamic> payload,
    required String programmeId,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = '${now.replaceAll(RegExp('[^0-9]'), '')}-'
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final sequence = nextApplicationSequence();
    final applicationNo = formatApplicationNumber(sequence);

    _db.execute(
      '''
      INSERT INTO applications
        (id, application_no, status, programme_id, full_name, phone_number,
         nin, area_community, payload, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        id,
        applicationNo,
        ApplicationStatus.submitted,
        programmeId,
        '${payload['fullName']}',
        '${payload['phoneNumber']}',
        '${payload['nin']}',
        '${payload['areaCommunity']}',
        jsonEncode(payload),
        now,
        now,
      ],
    );
    _db.execute(
      '''
      INSERT INTO application_official (application_id, verification_status)
      VALUES (?, ?)
      ''',
      <Object?>[id, ApplicationStatus.pending],
    );

    return getApplicationById(id)!;
  }

  List<Map<String, Object?>> listApplications({
    String? status,
    String? query,
    int limit = 50,
    int offset = 0,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (status != null && status.isNotEmpty) {
      if (!ApplicationStatus.all.contains(status)) {
        throw DatabaseException('Unknown status: $status');
      }
      where.add('a.status = ?');
      params.add(status);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add(
        '(a.application_no LIKE ? OR a.full_name LIKE ? OR a.phone_number LIKE ? '
        'OR a.nin LIKE ?)',
      );
      final like = '%${query.trim()}%';
      params.addAll(List<Object?>.filled(4, like));
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    params.addAll(<Object?>[limit.clamp(1, 200), offset.clamp(0, 100000)]);
    final rows = _db.select(
      '''
      SELECT a.id, a.application_no, a.status, a.programme_id, a.full_name,
             a.phone_number, a.area_community, a.created_at, a.updated_at,
             o.verification_status, o.approved_amount, o.expected_delivery_date
      FROM applications a
      LEFT JOIN application_official o ON o.application_id = a.id
      $clause
      ORDER BY a.created_at DESC
      LIMIT ? OFFSET ?
      ''',
      params,
    );
    return rows.map(_summaryToJson).toList();
  }

  int countApplications({String? status, String? query}) {
    final where = <String>[];
    final params = <Object?>[];
    if (status != null && status.isNotEmpty) {
      where.add('status = ?');
      params.add(status);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add(
        '(application_no LIKE ? OR full_name LIKE ? OR phone_number LIKE ? '
        'OR nin LIKE ?)',
      );
      final like = '%${query.trim()}%';
      params.addAll(List<Object?>.filled(4, like));
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final row = _db.select(
      'SELECT COUNT(*) AS n FROM applications $clause',
      params,
    );
    return row.first['n'] as int;
  }

  /// Returns the full application including the staff-only Section I block.
  Map<String, Object?>? getApplicationById(String id) {
    final rows = _db.select(
      '''
      SELECT a.*, o.received_by, o.verification_status, o.verification_date,
             o.approved_programme_id, o.approved_amount,
             o.expected_delivery_date, o.remarks, o.updated_by AS official_updated_by,
             o.updated_at AS official_updated_at
      FROM applications a
      LEFT JOIN application_official o ON o.application_id = a.id
      WHERE a.id = ?
      ''',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fullToJson(rows.first);
  }

  Map<String, Object?>? getApplicationByNo(String applicationNo) {
    final rows = _db.select(
      'SELECT id FROM applications WHERE application_no = ?',
      <Object?>[applicationNo],
    );
    if (rows.isEmpty) return null;
    return getApplicationById(rows.first['id'] as String);
  }

  /// Applies a staff status decision and Section I fields.
  ///
  /// Returns `null` when the application does not exist and throws
  /// [DatabaseException] for invalid statuses.
  Map<String, Object?>? updateApplicationStatus({
    required String id,
    required String status,
    required String staffUsername,
    String? remark,
    String? receivedBy,
    String? verificationDate,
    String? approvedProgrammeId,
    int? approvedAmount,
    String? expectedDeliveryDate,
  }) {
    if (!ApplicationStatus.all.contains(status)) {
      throw DatabaseException('Unknown status: $status');
    }
    if (approvedProgrammeId != null && !Programme.ids.contains(approvedProgrammeId)) {
      throw DatabaseException('Unknown programme: $approvedProgrammeId');
    }

    final existing = _db.select(
      'SELECT status FROM applications WHERE id = ?',
      <Object?>[id],
    );
    if (existing.isEmpty) return null;
    final previousStatus = existing.first['status'] as String;
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE applications SET status = ?, updated_at = ? WHERE id = ?',
        <Object?>[status, now, id],
      );
      _db.execute(
        '''
        UPDATE application_official SET
          verification_status = ?,
          received_by = COALESCE(?, received_by),
          verification_date = COALESCE(?, verification_date),
          approved_programme_id = COALESCE(?, approved_programme_id),
          approved_amount = COALESCE(?, approved_amount),
          expected_delivery_date = COALESCE(?, expected_delivery_date),
          remarks = COALESCE(?, remarks),
          updated_by = ?,
          updated_at = ?
        WHERE application_id = ?
        ''',
        <Object?>[
          status,
          receivedBy,
          verificationDate,
          approvedProgrammeId,
          approvedAmount,
          expectedDeliveryDate,
          remark,
          staffUsername,
          now,
          id,
        ],
      );
      _db.execute(
        '''
        INSERT INTO application_events
          (application_id, from_status, to_status, remark, staff_username, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[id, previousStatus, status, remark, staffUsername, now],
      );
      _db.execute('COMMIT');
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return getApplicationById(id);
  }

  List<Map<String, Object?>> applicationEvents(String applicationId) {
    final rows = _db.select(
      '''
      SELECT from_status, to_status, remark, staff_username, created_at
      FROM application_events
      WHERE application_id = ?
      ORDER BY created_at ASC, id ASC
      ''',
      <Object?>[applicationId],
    );
    return rows
        .map(
          (row) => <String, Object?>{
            'fromStatus': row['from_status'],
            'toStatus': row['to_status'],
            'remark': row['remark'],
            'staffUsername': row['staff_username'],
            'createdAt': row['created_at'],
          },
        )
        .toList();
  }

  Map<String, Object?>? staffCounts() {
    final rows = _db.select(
      '''
      SELECT status, COUNT(*) AS n FROM applications GROUP BY status
      ''',
    );
    final counts = <String, Object?>{};
    for (final status in ApplicationStatus.all) {
      counts[status] = 0;
    }
    for (final row in rows) {
      counts[row['status'] as String] = row['n'];
    }
    counts['total'] = rows.fold<int>(0, (sum, row) => sum + (row['n'] as int));
    return counts;
  }

  // ── Documents ───────────────────────────────────────────────────────────

  int insertDocument({
    required String applicationId,
    required String kind,
    required String fileName,
    required String storedPath,
  }) {
    _db.execute(
      '''
      INSERT INTO documents (application_id, kind, file_name, stored_path, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      <Object?>[
        applicationId,
        kind,
        fileName,
        storedPath,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    return _db.lastInsertRowId;
  }

  List<Map<String, Object?>> documentsFor(String applicationId) {
    final rows = _db.select(
      '''
      SELECT id, kind, file_name, created_at FROM documents
      WHERE application_id = ? ORDER BY id ASC
      ''',
      <Object?>[applicationId],
    );
    return rows
        .map(
          (row) => <String, Object?>{
            'id': row['id'],
            'kind': row['kind'],
            'fileName': row['file_name'],
            'createdAt': row['created_at'],
          },
        )
        .toList();
  }

  bool applicationExists(String id) =>
      _db.select('SELECT 1 FROM applications WHERE id = ?', <Object?>[id])
          .isNotEmpty;

  // ── Staff & sessions ────────────────────────────────────────────────────

  /// Creates a staff user with a bcrypt [passwordHash].
  int createStaff({
    required String username,
    required String passwordHash,
    required String fullName,
    String role = 'reviewer',
  }) {
    _db.execute(
      '''
      INSERT INTO staff_users (username, password_hash, full_name, role, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      <Object?>[
        username,
        passwordHash,
        fullName,
        role,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    return _db.lastInsertRowId;
  }

  Map<String, Object?>? staffByUsername(String username) {
    final rows = _db.select(
      'SELECT * FROM staff_users WHERE username = ?',
      <Object?>[username],
    );
    if (rows.isEmpty) return null;
    return _staffToJson(rows.first);
  }

  Map<String, Object?>? staffById(int id) {
    final rows = _db.select(
      'SELECT * FROM staff_users WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _staffToJson(rows.first);
  }

  void createSession({
    required String token,
    required int staffId,
    required Duration ttl,
  }) {
    final now = DateTime.now().toUtc();
    _db.execute(
      '''
      INSERT INTO sessions (token, staff_id, created_at, expires_at)
      VALUES (?, ?, ?, ?)
      ''',
      <Object?>[
        token,
        staffId,
        now.toIso8601String(),
        now.add(ttl).toIso8601String(),
      ],
    );
  }

  /// Returns the staff member for a valid, unexpired token.
  Map<String, Object?>? staffForToken(String token) {
    final rows = _db.select(
      '''
      SELECT s.token, s.expires_at, u.id, u.username, u.full_name, u.role
      FROM sessions s
      JOIN staff_users u ON u.id = s.staff_id
      WHERE s.token = ?
      ''',
      <Object?>[token],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final expiresAt = DateTime.tryParse(row['expires_at'] as String);
    if (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc())) {
      _db.execute('DELETE FROM sessions WHERE token = ?', <Object?>[token]);
      return null;
    }
    return <String, Object?>{
      'id': row['id'],
      'username': row['username'],
      'fullName': row['full_name'],
      'role': row['role'],
    };
  }

  void deleteSession(String token) =>
      _db.execute('DELETE FROM sessions WHERE token = ?', <Object?>[token]);

  // ── JSON shaping ────────────────────────────────────────────────────────

  Map<String, Object?> _staffToJson(Row row) => <String, Object?>{
        'id': row['id'],
        'username': row['username'],
        'passwordHash': row['password_hash'],
        'fullName': row['full_name'],
        'role': row['role'],
      };

  Map<String, Object?> _summaryToJson(Row row) => <String, Object?>{
        'id': row['id'],
        'applicationNo': row['application_no'],
        'status': row['status'],
        'programmeId': row['programme_id'],
        'fullName': row['full_name'],
        'phoneNumber': row['phone_number'],
        'areaCommunity': row['area_community'],
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
        'official': <String, Object?>{
          'verificationStatus': row['verification_status'],
          'approvedAmount': row['approved_amount'],
          'expectedDeliveryDate': row['expected_delivery_date'],
        },
      };

  Map<String, Object?> _fullToJson(Row row) {
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    return <String, Object?>{
      'id': row['id'],
      'applicationNo': row['application_no'],
      'status': row['status'],
      'programmeId': row['programme_id'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'application': payload,
      'official': <String, Object?>{
        'receivedBy': row['received_by'],
        'verificationStatus': row['verification_status'],
        'verificationDate': row['verification_date'],
        'approvedProgrammeId': row['approved_programme_id'],
        'approvedAmount': row['approved_amount'],
        'expectedDeliveryDate': row['expected_delivery_date'],
        'remarks': row['remarks'],
        'updatedBy': row['official_updated_by'],
        'updatedAt': row['official_updated_at'],
      },
    };
  }

  // ── Contact messages ─────────────────────────────────────────────────────

  /// Saves a contact-form message and returns the inserted row id.
  int insertContactMessage({
    required String name,
    required String phone,
    required String email,
    required String subject,
    required String message,
  }) {
    _db.execute(
      '''
      INSERT INTO contact_messages (name, phone, email, subject, message, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        name,
        phone,
        email,
        subject,
        message,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    final row = _db.select('SELECT last_insert_rowid() AS id');
    return row.first['id'] as int;
  }

  /// Lists all contact messages, newest first.
  List<Map<String, Object?>> listContactMessages({int limit = 100}) {
    final rows = _db.select(
      'SELECT * FROM contact_messages ORDER BY created_at DESC LIMIT ?',
      <Object?>[limit],
    );
    return rows
        .map((row) => <String, Object?>{
              'id': row['id'],
              'name': row['name'],
              'phone': row['phone'],
              'email': row['email'],
              'subject': row['subject'],
              'message': row['message'],
              'createdAt': row['created_at'],
            })
        .toList();
  }
}
