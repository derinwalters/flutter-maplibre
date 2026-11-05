import 'package:maplibre_platform_interface/src/platform_interface.dart';

/// The cookies MapLibre's own requests carry.
///
/// MapLibre loads a map's style, sources, glyphs and sprites, and every
/// download of an `OfflineManager`, through its own native network stack,
/// which shares nothing with Dart's HTTP clients. A cookie set here rides
/// those requests: to its host alone, under its path, over https only, until
/// it expires.
///
/// The cookie stays with the app's native network stack, so it outlives the
/// maps that used it until it expires or is replaced.
///
/// The [NetworkCookies] cannot be used on web.
///
/// {@category Basic}
abstract final class NetworkCookies {
  /// Whether network cookies are supported on the current platform.
  static bool get isSupported =>
      MapLibrePlatform.instance.networkCookiesAreSupported;

  /// Set the cookie [name]=[value] on every request MapLibre makes over https
  /// to [host] (that host alone, never a subdomain or a parent) for a path
  /// under [path], until [expires].
  ///
  /// A later call with the same [host], [path] and [name] replaces the cookie
  /// from the next request on, and one whose [expires] has passed removes it.
  static void set({
    required String host,
    required String path,
    required String name,
    required String value,
    required DateTime expires,
  }) => MapLibrePlatform.instance.setNetworkCookie(
    host: host,
    path: path,
    name: name,
    value: value,
    expires: expires,
  );
}
