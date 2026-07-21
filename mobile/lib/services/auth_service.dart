import '../models/app_user.dart';
import 'api_client.dart';

/// Result of a successful login (OTP verify or password login).
class LoginResult {
  final AppUser user;
  final String token;
  const LoginResult(this.user, this.token);
}

/// Result of requesting an OTP.
class OtpSendResult {
  final String message;
  final int resendAfter; // seconds before a resend is allowed
  const OtpSendResult(this.message, this.resendAfter);
}

/// Student authentication flows. Mirrors the web app's `/auth/*` calls.
class AuthService {
  final _dio = ApiClient.instance.dio;

  Future<OtpSendResult> sendOtp(String email) async {
    try {
      final res = await _dio.post('/auth/send-otp',
          data: {'email': email.trim().toLowerCase()});
      final data = res.data as Map<String, dynamic>;
      return OtpSendResult(
        (data['message'] ?? 'OTP sent').toString(),
        (data['resend_after'] is num) ? (data['resend_after'] as num).toInt() : 30,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<LoginResult> verifyOtp(String email, String otp) async {
    try {
      final res = await _dio.post('/auth/verify-otp',
          data: {'email': email.trim().toLowerCase(), 'otp': otp.trim()});
      return _parseLogin(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<String> register(String name, String email, String password) async {
    try {
      final res = await _dio.post('/auth/student-register', data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      return (data['message'] ?? 'Registration successful').toString();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<LoginResult> passwordLogin(String email, String password) async {
    try {
      final res = await _dio.post('/auth/student-login', data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      return _parseLogin(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  LoginResult _parseLogin(Map<String, dynamic> data) {
    final userJson = data['user'];
    final token = (data['token'] ?? '').toString();
    if (userJson is! Map || token.isEmpty) {
      throw ApiException('Unexpected server response. Please try again.');
    }
    return LoginResult(
      AppUser.fromJson(userJson.cast<String, dynamic>()),
      token,
    );
  }
}
