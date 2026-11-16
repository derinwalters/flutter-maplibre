part of 'map_options.dart';

/// The gestures that move the map camera, all on by default.
///
/// A gesture moves the camera only along the [MapMovements] that are on.
///
/// ```dart
/// MapOptions(
///   // No zooming with the scroll wheel.
///   gestures: MapGestures(scrollWheel: false),
/// )
/// ```
///
/// {@category Basic}
@immutable
class MapGestures {
  /// Turns every gesture on by default.
  const MapGestures({
    this.drag = true,
    this.fling = true,
    this.pinch = true,
    this.scrollWheel = true,
    this.doubleTap = true,
    this.doubleTapDrag = true,
    this.secondaryDrag = true,
    this.twoFingerDrag = true,
    this.rotateThreshold = 15,
  }) : assert(rotateThreshold >= 0, 'rotateThreshold must not be negative');

  /// Turns every gesture off by default.
  ///
  /// For example, `MapGestures.none(drag: true)` only drags.
  const MapGestures.none({
    this.drag = false,
    this.fling = false,
    this.pinch = false,
    this.scrollWheel = false,
    this.doubleTap = false,
    this.doubleTapDrag = false,
    this.secondaryDrag = false,
    this.twoFingerDrag = false,
    this.rotateThreshold = 15,
  }) : assert(rotateThreshold >= 0, 'rotateThreshold must not be negative');

  /// Drag one finger or the mouse to pan.
  final bool drag;

  /// Keep the map moving after a fast [drag] or [pinch] is released.
  final bool fling;

  /// Move two fingers on the screen or the trackpad: moving them together
  /// pans, spreading or pinching them zooms, and twisting them rotates.
  final bool pinch;

  /// Scroll with a mouse wheel to zoom.
  final bool scrollWheel;

  /// Double tap or double click to zoom in.
  final bool doubleTap;

  /// Double tap, keep the finger down and drag it to zoom: down zooms in, up
  /// zooms out.
  final bool doubleTapDrag;

  /// Drag with the right mouse button, or with the left button while Ctrl is
  /// held: sideways to rotate, up or down to tilt.
  final bool secondaryDrag;

  /// Drag two fingers side by side up or down to tilt.
  final bool twoFingerDrag;

  /// Degrees that two fingers of a [pinch] twist before it rotates the map,
  /// so that a pinch that only zooms or pans doesn't turn the map by
  /// accident. Once the twist passes it, the map turns with the fingers until
  /// they lift. 0 rotates right away.
  final double rotateThreshold;

  /// A copy with the given gestures replaced.
  MapGestures copyWith({
    bool? drag,
    bool? fling,
    bool? pinch,
    bool? scrollWheel,
    bool? doubleTap,
    bool? doubleTapDrag,
    bool? secondaryDrag,
    bool? twoFingerDrag,
    double? rotateThreshold,
  }) => MapGestures(
    drag: drag ?? this.drag,
    fling: fling ?? this.fling,
    pinch: pinch ?? this.pinch,
    scrollWheel: scrollWheel ?? this.scrollWheel,
    doubleTap: doubleTap ?? this.doubleTap,
    doubleTapDrag: doubleTapDrag ?? this.doubleTapDrag,
    secondaryDrag: secondaryDrag ?? this.secondaryDrag,
    twoFingerDrag: twoFingerDrag ?? this.twoFingerDrag,
    rotateThreshold: rotateThreshold ?? this.rotateThreshold,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapGestures &&
          drag == other.drag &&
          fling == other.fling &&
          pinch == other.pinch &&
          scrollWheel == other.scrollWheel &&
          doubleTap == other.doubleTap &&
          doubleTapDrag == other.doubleTapDrag &&
          secondaryDrag == other.secondaryDrag &&
          twoFingerDrag == other.twoFingerDrag &&
          rotateThreshold == other.rotateThreshold;

  @override
  int get hashCode => Object.hash(
    drag,
    fling,
    pinch,
    scrollWheel,
    doubleTap,
    doubleTapDrag,
    secondaryDrag,
    twoFingerDrag,
    rotateThreshold,
  );

  @override
  String toString() =>
      'MapGestures(drag: $drag, fling: $fling, pinch: $pinch, '
      'scrollWheel: $scrollWheel, doubleTap: $doubleTap, '
      'doubleTapDrag: $doubleTapDrag, secondaryDrag: $secondaryDrag, '
      'twoFingerDrag: $twoFingerDrag, rotateThreshold: $rotateThreshold)';
}
