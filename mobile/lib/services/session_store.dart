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
  static const _kBaseUrl = 'server_base_url';

  late SharedPreferences _prefs;
  String? _token;
  AppUser? _user;
  String? _baseUrlOverride;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString(_kToken);
    _baseUrlOverride = _prefs.getString(_kBaseUrl);
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
  /// Effective base URL: the user override if set, else the platform default.
  String get baseUrl =>
      (_baseUrlOverride?.isNotEmpty ?? false) ? _baseUrlOverride! : Env.defaultBaseUrl;

  bool get hasCustomBaseUrl => _baseUrlOverride?.isNotEmpty ?? false;

  Future<void> setBaseUrl(String? url) async {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      _baseUrlOverride = null;
      await _prefs.remove(_kBaseUrl);
    } else {
      _baseUrlOverride = normalized;
      await _prefs.setString(_kBaseUrl, normalized);
    }
  }
}
