import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Holds the signed-in staff session and notifies the router on change.
class Session extends ChangeNotifier {
  Session(this.api);

  final ApiClient api;

  StaffSession? _staff;
  bool _restored = false;
  bool _busy = false;

  StaffSession? get staff => _staff;
  bool get isSignedIn => _staff != null;
  bool get restored => _restored;
  bool get busy => _busy;

  static const _tokenKey = 'teamak_staff_token';

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
