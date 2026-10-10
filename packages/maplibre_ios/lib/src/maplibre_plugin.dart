import 'package:maplibre_ios/src/map_state.dart';
import 'package:maplibre_ios/src/maplibre_ffi.g.dart';
import 'package:maplibre_ios/src/offline_manager.dart';
import 'package:maplibre_ios/src/permission_manager.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:objective_c/objective_c.dart';

/// iOS implementation of the federated MapLibre plugin.
final class MapLibrePlugin extends MapLibrePlatform {
  /// This static method registers [MapLibrePlugin] when running on iOS.
  static void registerWith() => MapLibrePlatform.instance = MapLibrePlugin();

  @override
  MapLibreMapState createWidgetState() => MapLibreMapStateIos();

  @override
  Future<OfflineManager> createOfflineManager() =>
      OfflineManagerIos.createInstance();

  @override
  PermissionManager createPermissionManager() => const PermissionManagerIos();

  @override
  void setNetworkCookie({
    required String host,
    required String path,
    required String name,
    required String value,
    required DateTime expires,
  }) {
    final set = Helpers.setNetworkCookieWithHost(
      host.toNSString(),
      path: path.toNSString(),
      name: name.toNSString(),
      value: value.toNSString(),
      expires: expires.toNSDate(),
    );
    if (!set) {
      throw StateError(
        "MapLibre's network configuration holds no cookie storage, "
        'or the cookie for $host$path is malformed.',
      );
    }
  }

  @override
  bool get offlineManagerIsSupported => true;

  @override
  bool get networkCookiesAreSupported => true;

  @override
  bool get permissionManagerIsSupported => false;

  @override
  bool get userLocationIsSupported => true;
}
