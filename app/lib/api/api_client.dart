import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Raised when the API returns an error response.
class ApiException implements Exception {
  ApiException(this.message, {this.errors = const {}, this.statusCode});

  final String message;
  final Map<String, String> errors;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE',
              defaultValue: 'http://localhost:8080',
            );

  final http.Client _client;
  final String baseUrl;

  String? token;

  /// Called when a request carrying a token is rejected with 401.
  ///
  /// The session installs this so an expired token clears itself instead of
  /// stranding the staff area behind a failed request on every call.
  void Function()? onUnauthorized;

  /// Resolves [path] against the configured base.
  ///
  /// An empty base means "same origin": the path is resolved against the page
  /// URL instead, so a build served behind a reverse proxy or a single-host
  /// demo keeps working when the API is not on its own domain.
  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.isEmpty ? Uri.base : Uri.parse(baseUrl);
    return base.resolve(path).replace(queryParameters: query);
  }

  Map<String, String> get _headers => <String, String>{
        'content-type': 'application/json; charset=utf-8',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    final request = http.Request(method, uri);
    if (auth || token != null) {
      request.headers.addAll(_headers);
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes)) as dynamic;

    if (response.statusCode >= 400) {
      // A password rejected at sign-in is not a dead session: the token in
      // play belongs to an earlier, still valid, sign-in.
      if (response.statusCode == 401 &&
          token != null &&
          path != '/auth/login') {
        onUnauthorized?.call();
      }
      final map = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      final errors = <String, String>{};
      final rawErrors = map?['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) => errors['$key'] = '$value');
      }
      throw ApiException(
        '${map?['error'] ?? 'Request failed (${response.statusCode})'}',
        errors: errors,
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, Object body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Object body) =>
      _send('PATCH', path, body: body);

  // ── Endpoints ──────────────────────────────────────────────────────────

  Future<List<Programme>> fetchProgrammes() async {
    final json = await get('/programmes');
    final list = (json['programmes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Programme.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<StaffSession> login({
    required String username,
    required String password,
  }) async {
    final json = await _send(
      'POST',
      '/auth/login',
      body: <String, Object?>{'username': username, 'password': password},
      auth: false,
    );
    final session = StaffSession.fromJson(json);
    token = session.token;
    return session;
  }

  /// Ends the session on the server, then drops the token locally.
  ///
  /// The server call matters: without it the token would stay valid until its
  /// 12-hour TTL lapsed, so any copy of it kept working after sign-out. A
  /// failed call still clears the local token so the UI cannot get stuck.
  Future<void> logout() async {
    final current = token;
    token = null;
    if (current == null) return;
    try {
      await _send('POST', '/auth/logout');
    } on ApiException {
      // Already expired or revoked server-side; nothing further to do.
    }
  }

  Future<ApplicationDetail> submitApplication(Map<String, dynamic> payload) async {
    final json = await post('/applications', payload);
    return ApplicationDetail.fromJson(json);
  }

  /// Submits a contact-form message. Returns a human-readable success string.
  Future<String> submitContact({
    required String name,
    required String phone,
    required String email,
    required String subject,
    required String message,
  }) async {
    final json = await post('/contact', <String, Object?>{
      'name': name,
      'phone': phone,
      'email': email,
      'subject': subject,
      'message': message,
    });
    return '${json['message'] ?? 'Thank you! Your message has been received.'}';
  }

  Future<ApplicationListResult> listApplications({
    String? status,
    String? query,
    int limit = 100,
  }) {
    final parameters = <String, String>{'limit': '$limit'};
    final statusFilter = status?.trim();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      parameters['status'] = statusFilter;
    }
    final search = query?.trim();
    if (search != null && search.isNotEmpty) {
      parameters['q'] = search;
    }
    return get('/applications', query: parameters)
        .then(ApplicationListResult.fromJson);
  }

  Future<ApplicationDetail> fetchApplication(String id) =>
      get('/applications/$id').then(ApplicationDetail.fromJson);

  /// Looks up an application for the person who filed it.
  ///
  /// There is no staff session on this path, so the API only answers when the
  /// number and the submitted phone number agree — the pair in this request
  /// is the credential.
  Future<ApplicationDetail> trackApplication({
    required String applicationNo,
    required String phone,
  }) =>
      post('/track', <String, Object?>{
        'applicationNo': applicationNo,
        'phone': phone,
      }).then(ApplicationDetail.fromJson);

  /// Fetches the staff inbox of submitted contact-form messages.
  Future<List<ContactMessage>> fetchMessages({int limit = 100}) async {
    final json = await get('/contact', query: <String, String>{
      'limit': '$limit',
    });
    return (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ContactMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ApplicationDetail> updateStatus({
    required String id,
    required String status,
    String? remark,
    String? receivedBy,
    String? verificationDate,
    String? approvedProgrammeId,
    int? approvedAmount,
    String? expectedDeliveryDate,
  }) =>
      patch(
        '/applications/$id/status',
        <String, Object?>{
          'status': status,
          if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
          if (receivedBy != null && receivedBy.trim().isNotEmpty)
            'receivedBy': receivedBy.trim(),
          if (verificationDate != null && verificationDate.isNotEmpty)
            'verificationDate': verificationDate,
          'approvedProgrammeId': ?approvedProgrammeId,
          'approvedAmount': ?approvedAmount,
          if (expectedDeliveryDate != null && expectedDeliveryDate.isNotEmpty)
            'expectedDeliveryDate': expectedDeliveryDate,
        },
      ).then(ApplicationDetail.fromJson);
}
