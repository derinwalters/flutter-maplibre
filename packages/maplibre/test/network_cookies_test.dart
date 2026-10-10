import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart'
    show MapLibrePlatform;

final class _RecordingPlatform extends MapLibrePlatform {
  final calls = <Map<String, Object>>[];

  @override
  void setNetworkCookie({
    required String host,
    required String path,
    required String name,
    required String value,
    required DateTime expires,
  }) => calls.add({
    'host': host,
    'path': path,
    'name': name,
    'value': value,
    'expires': expires,
  });

  @override
  bool get networkCookiesAreSupported => true;
}

void main() {
  group('NetworkCookies', () {
    late MapLibrePlatform original;
    setUp(() => original = MapLibrePlatform.instance);
    tearDown(() => MapLibrePlatform.instance = original);

    test('is unsupported without a platform implementation', () {
      expect(NetworkCookies.isSupported, isFalse);
      expect(
        () => NetworkCookies.set(
          host: 'example.com',
          path: '/',
          name: 'n',
          value: 'v',
          expires: DateTime.utc(2026),
        ),
        throwsUnsupportedError,
      );
    });

    test('hands the cookie to the platform as given', () {
      final platform = _RecordingPlatform();
      MapLibrePlatform.instance = platform;
      final expires = DateTime.utc(2026, 10, 10, 13);
      NetworkCookies.set(
        host: 'tiles.example.com',
        path: '/tiles/4/',
        name: 'Cloud-CDN-Cookie',
        value: 'URLPrefix=aHR0cHM6Ly8:Expires=1:KeyName=k:Signature=c2ln',
        expires: expires,
      );
      expect(NetworkCookies.isSupported, isTrue);
      expect(platform.calls, [
        {
          'host': 'tiles.example.com',
          'path': '/tiles/4/',
          'name': 'Cloud-CDN-Cookie',
          'value': 'URLPrefix=aHR0cHM6Ly8:Expires=1:KeyName=k:Signature=c2ln',
          'expires': expires,
        },
      ]);
    });
  });
}
