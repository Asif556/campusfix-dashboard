import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import '../models/app_user.dart';

/// Persists the session (token + cached user) and the user-overridable server
/// base URL. Values are cached in memory after [init] so the API client can read
/// the token/base URL synchronously on every request.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _kToken = 'auth_token';
  static const _kUser = 'student_user';
  static const _kLegacyBaseUrl = 'server_base_url';

  late SharedPreferences _prefs;
  String? _token;
  AppUser? _user;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString(_kToken);
    // Drop any server address saved by older builds — the URL is now fixed.
    await _prefs.remove(_kLegacyBaseUrl);
    final userRaw = _prefs.getString(_kUser);
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        _user = AppUser.fromJson(
            jsonDecode(userRaw) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
  }

  // ── Auth ────────────────────────────────────────────────────────────────
  String? get token => _token;
  AppUser? get user => _user;
  bool get isLoggedIn => (_token?.isNotEmpty ?? false) && _user != null;

  Future<void> saveSession(String token, AppUser user) async {
    _token = token;
    _user = user;
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }

  // ── Server URL ──────────────────────────────────────────────────────────
  /// The fixed hosted backend URL. Not user-configurable.
  String get baseUrl => Env.baseUrl;
}
