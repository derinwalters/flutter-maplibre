import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:maplibre_platform_interface/src/widget/inherited_model.dart';

part 'map_gestures.dart';
part 'map_movements.dart';

/// The [MapOptions] class is used to set default values for the [MapLibreMap]
/// widget.
///
/// {@category Basic}
@immutable
class MapOptions {
  /// Creates a new [MapOptions] instance. See fields for more information.
  const MapOptions({
    this.style = MapStyle.demo,
    this.initCamera,
    this.minZoom = 0,
    this.maxZoom = 22,
    this.minPitch = 0,
    this.maxPitch = 60,
    this.maxBounds,
    this.movements = const MapMovements(),
    this.gestures = const MapGestures(),
    this.fastPforEnabled = false,
    this.localIdeographFontFamily,
  });

  /// Find the [MapOptions] of the closest [MapLibreMap] in the widget tree.
  /// Returns null if called outside of the [MapLibreMap.children].
  static MapOptions? maybeOf(BuildContext context) =>
      MapLibreInheritedModel.maybeMapControllerOf(context)?.options;

  /// Find the [MapOptions] of the closest [MapLibreMap] in the widget tree.
  /// Throws an [StateError] if called outside of the [MapLibreMap.children].
  static MapOptions of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('Unable to find an instance of MapOptions'));

  /// The style of the map. Defaults to the MapLibre demo style
  /// ([MapStyle.demo]).
  ///
  /// The map loads a new style when this changes, which removes the layers
  /// added with [StyleLayers.add]. [MapLibreMap.onStyleLoaded] reports each
  /// loaded style.
  final MapStyle style;

  /// The camera that the map starts with, at a position
  /// ([CameraUpdate.position]) or fitted to a target, such as bounds
  /// ([CameraUpdate.bounds]).
  ///
  /// If null, the map starts at the camera of its style (the style's
  /// `center`, `zoom`, `bearing` and `pitch`). Changes after the map was
  /// created have no effect; move the camera with [MapController] instead.
  final CameraUpdate? initCamera;

  /// The minimum zoom level. Allowed values are 0-24. Defaults to 0.
  final double minZoom;

  /// The maximum zoom level. Allowed values are 0-24. Defaults to 22.
  final double maxZoom;

  /// The minimum camera pitch / tilt. Allowed values on web are 0-85. Allowed
  /// values on other platforms are 0-60, bigger values will get ignored.
  ///
  /// Defaults to 0.
  final double minPitch;

  /// The maximum camera pitch / tilt. Allowed values on web are 0-85. Allowed
  /// values on other platforms are 0-60, bigger values will get ignored.
  final double maxPitch;

  /// The maximum bounding box of the map camera. No constraints are in place
  /// if set to `null`.
  final GeoBox? maxBounds;

  /// How the user may move the camera, whatever the gesture.
  final MapMovements movements;

  /// The gestures that move the camera.
  final MapGestures gestures;

  /// Whether the map decodes MapLibre Tile (MLT) vector tiles that use
  /// FastPFOR integer encodings. Defaults to false.
  ///
  /// Without it, the map drops each such tile with the warning
  /// `MLT parse failed: FastPFOR decoding is not enabled`. Servers such as
  /// Martin use FastPFOR when they encode MLT, so enable it for their tiles.
  ///
  /// Read once, when the map is created: changing it later has no effect.
  ///
  /// Not needed on web, where FastPFOR decoding is always enabled.
  final bool fastPforEnabled;

  /// The fonts that draw CJK ideographs, kana and Hangul on the device
  /// instead of from the style's glyphs, as a CSS font-family list such as
  /// `"'Hiragino Sans', sans-serif"`. A generic family, such as `sans-serif`,
  /// is the system font, whose fallbacks pick the CJK face of the device's
  /// language. The map then downloads only the glyph ranges of other scripts,
  /// and shows CJK labels without waiting for them.
  ///
  /// Null, the default, keeps the platform's own: web draws these characters
  /// with the browser's `sans-serif` font, iOS and macOS with the style's
  /// glyphs.
  ///
  /// Only on iOS, macOS and web; the other platforms draw the style's glyphs.
  /// Read once, when the map is created. On iOS and macOS the fonts are the
  /// app's: a map created later without them draws with them too.
  final String? localIdeographFontFamily;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapOptions &&
          style == other.style &&
          initCamera == other.initCamera &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom &&
          minPitch == other.minPitch &&
          maxPitch == other.maxPitch &&
          maxBounds == other.maxBounds &&
          movements == other.movements &&
          gestures == other.gestures &&
          fastPforEnabled == other.fastPforEnabled &&
          localIdeographFontFamily == other.localIdeographFontFamily;

  @override
  int get hashCode => Object.hash(
    style,
    initCamera,
    minZoom,
    maxZoom,
    minPitch,
    maxPitch,
    maxBounds,
    movements,
    gestures,
    fastPforEnabled,
    localIdeographFontFamily,
  );
}
