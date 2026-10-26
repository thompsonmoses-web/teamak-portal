import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Holds the signed-in staff session and notifies the router on change.
class Session extends ChangeNotifier {
  Session(this.api) {
    // The API reports 401 for any request that still carries a token it no
    // longer honours. Clearing here keeps a dead token out of storage and
    // lets the router's redirect fall through to the sign-in form.
    api.onUnauthorized = _expire;
  }

  final ApiClient api;

  StaffSession? _staff;
  bool _restored = false;
  bool _busy = false;

  StaffSession? get staff => _staff;
  bool get isSignedIn => _staff != null;
  bool get restored => _restored;
  bool get busy => _busy;

  static const _tokenKey = 'teamak_staff_token';

  /// Drops a session the API has rejected.
  ///
  /// Deliberately never calls back into the API: the request that raised the
  /// 401 already threw, and calling `/auth/logout` with the same dead token
  /// would only raise a second one.
  Future<void> _expire() async {
    final wasSignedIn = _staff != null || api.token != null;
    api.token = null;
    _staff = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {
      // Storage can be unavailable in a restricted embedder; the in-memory
      // clear above still ends this run's session.
    }
    if (wasSignedIn) notifyListeners();
  }

  /// Rehydrates a previously stored token from local storage.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        api.token = token;
        final me = await api.get('/auth/me');
        _staff = StaffSession(
          token: token,
          username: '${me['username']}',
          fullName: '${me['fullName']}',
          role: '${me['role']}',
        );
      }
    } catch (_) {
      api.token = null;
      _staff = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } finally {
      // The Pages preview ships the demo backend — seeded accounts, per
      // visitor data — inside the same bundle, and prints its credentials on
      // the form, so there is no real account to protect: the demo build
      // signs itself in instead of asking anyone to type. Compile-time
      // check: a build pointed at the real API never takes this branch, and
      // if the demo sign-in ever failed the form below remains the
      // fallback.
      if (_staff == null &&
          const String.fromEnvironment('API_BASE') == demoApiBase) {
        try {
          await signIn(username: 'demo', password: 'demo1234');
        } catch (_) {
          // Leave the visitor at the sign-in form; nothing else to clean up.
        }
      }
      _restored = true;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final session = await api.login(username: username, password: password);
      _staff = session;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, session.token);
      return true;
    } on ApiException {
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _staff = null;
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
