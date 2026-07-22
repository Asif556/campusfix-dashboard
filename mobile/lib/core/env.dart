/// Environment configuration and URL helpers.
///
/// The app talks to the hosted CampusFix backend. The API is served under
/// `/campusfix/api` and static uploads under `/campusfix/uploads`. The server
/// address is fixed — there is no in-app configuration.
class Env {
  Env._();

  /// Hosted backend origin (scheme + host, no trailing slash).
  static const String origin = 'https://server.uemcseaiml.org';

  static const String apiSuffix = '/campusfix/api';

  /// The single, fixed base URL the whole app talks to.
  static const String baseUrl = '$origin$apiSuffix';

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
