import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Owns the authenticated session and exposes the auth flows to the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // A protected 401 (expired token) forces a clean logout + redirect.
    ApiClient.instance.onUnauthorized = () {
      if (_status == AuthStatus.authenticated) {
        _sessionExpired = true;
        logout();
      }
    };
  }

  final _auth = AuthService();
  final _store = SessionStore.instance;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _sessionExpired = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// Set once when a session expires mid-use; the login screen reads and clears
  /// it to show a one-time notice.
  bool consumeSessionExpired() {
    final v = _sessionExpired;
    _sessionExpired = false;
    return v;
  }

  /// Restore any persisted session on app start.
  Future<void> bootstrap() async {
    if (_store.isLoggedIn) {
      _user = _store.user;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── OTP flow ──────────────────────────────────────────────────────────────
  Future<OtpSendResult> sendOtp(String email) => _auth.sendOtp(email);

  Future<void> verifyOtp(String email, String otp) async {
    final result = await _auth.verifyOtp(email, otp);
    await _completeLogin(result);
  }

  // ── Password flow ──────────────────────────────────────────────────────────
  Future<void> passwordLogin(String email, String password) async {
    final result = await _auth.passwordLogin(email, password);
    await _completeLogin(result);
  }

  Future<String> register(String name, String email, String password) =>
      _auth.register(name, email, password);

  Future<void> _completeLogin(LoginResult result) async {
    await _store.saveSession(result.token, result.user);
    _user = result.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _store.clearSession();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
