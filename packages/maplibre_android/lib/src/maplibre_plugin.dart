import 'package:jni/jni.dart';
import 'package:maplibre_android/src/functions.dart';
import 'package:maplibre_android/src/jni.g.dart' as jni;
import 'package:maplibre_android/src/map_state.dart';
import 'package:maplibre_android/src/offline_manager.dart';
import 'package:maplibre_android/src/permission_manager.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// Android implementation of the federated MapLibre plugin.
final class MapLibrePlugin extends MapLibrePlatform {
  /// This static method registers [MapLibrePlugin] when running on Android.
  static void registerWith() => MapLibrePlatform.instance = MapLibrePlugin();

  @override
  MapLibreMapState createWidgetState() => MapLibreMapStateAndroid();

  @override
  Future<OfflineManager> createOfflineManager() =>
      OfflineManagerAndroid.createInstance();

  @override
  PermissionManager createPermissionManager() => PermissionManagerAndroid();

  @override
  void setNetworkCookie({
    required String host,
    required String path,
    required String name,
    required String value,
    required DateTime expires,
  }) => using((arena) {
    // MapLibre.getInstance needs to be called before replacing its HTTP client:
    // the request class reads the app context when it loads, and a load that
    // fails leaves every later MapLibre request without a class.
    jni.MapLibre.getInstance(
      getJContext()..releasedBy(arena),
    ).releasedBy(arena);
    jni.NetworkCookies.set(
      host.toJString()..releasedBy(arena),
      path.toJString()..releasedBy(arena),
      name.toJString()..releasedBy(arena),
      value.toJString()..releasedBy(arena),
      expires.millisecondsSinceEpoch,
    );
  });

  @override
  bool get offlineManagerIsSupported => true;

  @override
  bool get networkCookiesAreSupported => true;

  @override
  bool get permissionManagerIsSupported => true;

  @override
  bool get userLocationIsSupported => true;
}
