import 'dart:io' show Platform;

/// Environment defaults and URL helpers.
///
/// The backend serves the API under `/campusfix/api` and static uploads under
/// `/campusfix/uploads`. On a device/emulator `127.0.0.1` points at the device
/// itself, so the Android emulator must reach the host via `10.0.2.2`. The
/// effective base URL is user-overridable from the in-app Settings screen; these
/// are only the first-run defaults.
class Env {
  Env._();

  static const String apiSuffix = '/campusfix/api';

  /// Sensible first-run default for the current platform.
  static String get defaultBaseUrl {
    if (Platform.isAndroid) {
      // Android emulator loopback alias for the host machine.
      return 'http://10.0.2.2:5000$apiSuffix';
    }
    // iOS simulator and everything else share the host loopback.
    return 'http://127.0.0.1:5000$apiSuffix';
  }

  /// Strip the `/campusfix/api` suffix to get the server origin, used to build
  /// absolute URLs for static assets like uploaded photos.
  static String originFrom(String baseUrl) {
    final trimmed = baseUrl.replaceAll(RegExp(r'/campusfix/api/?$'), '');
    return trimmed.replaceAll(RegExp(r'/$'), '');
  }

  /// Resolve a stored complaint photo path to an absolute, loadable URL.
  ///
  /// The backend stores paths like `/uploads/<name>` but serves them at
  /// `<origin>/campusfix/uploads/<name>`.
  static String? resolvePhotoUrl(String baseUrl, String? photo) {
    if (photo == null || photo.isEmpty) return null;
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(photo)) {
      return photo; // already absolute
    }
    final filename = photo.split('/').where((s) => s.isNotEmpty).lastOrNull;
    if (filename == null || filename.isEmpty) return null;
    return '${originFrom(baseUrl)}/campusfix/uploads/$filename';
  }
}

extension _LastOrNull<E> on Iterable<E> {
  E? get lastOrNull => isEmpty ? null : last;
}
