import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// Zoom levels per logical pixel of mouse wheel scroll, as MapLibre GL JS
/// uses for wheel zoom.
const double _wheelZoomRate = 1 / 450;

/// Degrees of bearing per logical pixel of horizontal mouse drag, and of
/// pitch per pixel of vertical drag, as in MapLibre GL JS.
const _rotateDegreesPerPixel = 0.8;
const _pitchDegreesPerPixel = 0.5;

const _doubleTapZoomDuration = Duration(milliseconds: 300);

/// Logical pixels of vertical drag per zoom level in a double-tap-and-drag
/// zoom.
const _quickZoomPixelsPerLevel = 150.0;

/// Degrees of pitch per logical pixel that two fingers move vertically.
const _shoveDegreesPerPixel = 0.25;

/// Logical pixels both fingers move vertically before a two-finger drag
/// tilts the map.
const _shoveSlop = 10.0;

/// Radians two fingers must twist, from where the pinch began, before the
/// map turns with them. A pinch or a two-finger drag twists a little
/// whatever the hand means, so a smaller turn only zooms or pans, and the
/// bearing stays where it was. Past it the map follows the fingers from where
/// they crossed, so it does not jump.
const double _rotateSlop = 14 * pi / 180;

/// A long press that only one finger can make.
///
/// The long press recognizer times the first finger alone, and when its
/// deadline passes it wins the gesture arena over every other recognizer,
/// whatever else has landed meanwhile. So two fingers resting on the map for
/// half a second before a pinch, twist or tilt were a long press, and the
/// pinch never moved the camera. A second finger landing while the hold is
/// still pending ends it instead; once the hold has been accepted it is left
/// as it is.
class _OneFingerLongPressRecognizer extends LongPressGestureRecognizer {
  _OneFingerLongPressRecognizer();

  // Whether the arena has gone to the hold, which a second finger cannot
  // take back.
  var _held = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (state == GestureRecognizerState.possible && !_held) {
      resolve(GestureDisposition.rejected);
      return;
    }
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _held = true;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _held = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

/// Recognizes map gestures on [child] and hands their camera changes to
/// [camera].
///
/// Flutter hit-tests the pointers, so widgets over the map keep theirs. The
/// gestures follow the platform conventions: a drag pans, from where the
/// finger touched down if [MapGestures.panPhysics] follow it from there and
/// from where the drag was recognized otherwise, a pinch zooms and,
/// once the fingers have twisted 14 degrees, turns the map, a scroll wheel
/// and a double tap zoom, a double tap and drag zooms, two fingers side by
/// side dragged vertically tilt, and a right-button or Ctrl + left-button
/// mouse drag rotates and tilts. A long click is a hold of one finger: a
/// second finger landing during the hold ends it, and leaves the fingers to
/// the pinch, twist or tilt. [gestures] turns them off by kind.
class MapGestureDetector extends StatefulWidget {
  /// Creates a gesture layer over a map.
  const MapGestureDetector({
    required this.gestures,
    required this.camera,
    required this.toLngLat,
    required this.child,
    this.onEvent,
    super.key,
  });

  /// The gestures that move the camera.
  final MapGestures gestures;

  /// Applies the camera changes.
  final GestureCameraSink camera;

  /// The location at a screen point, or null while the map can't tell.
  final Geographic? Function(Offset screenPoint) toLngLat;

  /// Receives clicks, double clicks, secondary and long clicks.
  final MapEventCallback? onEvent;

  /// The map.
  final Widget child;

  /// Logical pixels per pixel of a wheel event's scroll delta, so that a
  /// wheel notch zooms as far as in MapLibre GL JS.
  ///
  /// Flutter web takes the CSS pixels of a browser wheel event as physical
  /// pixels and divides them by the device pixel ratio, except on macOS,
  /// where it multiplies them first. So on a 2x screen a wheel notch would
  /// zoom half as far.
  @visibleForTesting
  static double wheelPixelScale({
    required bool isWeb,
    required TargetPlatform platform,
    required double devicePixelRatio,
  }) => isWeb && platform != TargetPlatform.macOS ? devicePixelRatio : 1;

  @override
  State<MapGestureDetector> createState() => _MapGestureDetectorState();
}

class _MapGestureDetectorState extends State<MapGestureDetector> {
  var _gestureActive = false;

  // Scale gesture state, relative to the previous update.
  var _lastScale = 1.0;

  // The twist of the fingers: the recognizer's last rotation, the radians
  // they have turned since the pinch began, how many of those the map has
  // turned by, and whether they have passed [_rotateSlop].
  var _lastRotation = 0.0;
  var _twist = 0.0;
  var _turned = 0.0;
  var _rotating = false;

  // Where the first update of a one-finger drag pans the map from: where the
  // finger touched down, if the pan physics follow it from there, so the
  // pixels it moved before the drag was recognized move the map too.
  Offset? _panFromTouchDown;

  // The mouse pointer that rotates and tilts: a right-button or Ctrl and
  // left-button drag.
  int? _secondaryPointer;

  // Touch pointers that are down, and where the only one went down, to tell
  // a tap from a drag and to pan a drag from there.
  final _touchPointers = <int>{};
  Offset? _touchDownPosition;

  // The last tap's release, which a second touch nearby starts a quick zoom
  // from.
  Duration? _lastTapUpTime;
  Offset? _lastTapUpPosition;

  // Double-tap-and-drag zoom: the second tap's pointer and position, and
  // whether it has moved far enough to zoom.
  int? _quickZoomPointer;
  Offset? _quickZoomAnchor;
  var _quickZooming = false;

  /// Where the second tap of a double tap went down.
  Offset? _doubleTapPosition;

  // Two-finger tilt ("shove"): where each of the two fingers was when the
  // second went down, where it is now, and whether the gesture tilts, or was
  // found to be a pinch or rotation instead.
  final _shoveStart = <int, Offset>{};
  final _shovePosition = <int, Offset>{};
  var _shoving = false;
  var _shoveRejected = false;

  MapGestures get _gestures => widget.gestures;

  GestureCameraSink get _camera => widget.camera;

  @override
  void dispose() {
    _endGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = _gestures;
    final scales = gestures.pan || gestures.zoom || gestures.rotate;
    // The whole map takes part in gestures, whatever its child hit-tests.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _OneFingerLongPressRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _OneFingerLongPressRecognizer
              >(
                _OneFingerLongPressRecognizer.new,
                (recognizer) =>
                    recognizer.onLongPressStart = (details) =>
                        _emitUserInput(details.localPosition, _longClick),
              ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _emitUserInput(details.localPosition, _click),
          onSecondaryTapUp: (details) =>
              _emitUserInput(details.localPosition, _secondaryClick),
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: _onDoubleTap,
          onScaleStart: scales ? _onScaleStart : null,
          onScaleUpdate: scales ? _onScaleUpdate : null,
          onScaleEnd: scales ? _onScaleEnd : null,
          child: widget.child,
        ),
      ),
    );
  }

  static MapEventUserInput _click(Geographic point, Offset screenPoint) =>
      MapEventClick(point: point, screenPoint: screenPoint);

  static MapEventUserInput _secondaryClick(
    Geographic point,
    Offset screenPoint,
  ) => MapEventSecondaryClick(point: point, screenPoint: screenPoint);

  static MapEventUserInput _longClick(Geographic point, Offset screenPoint) =>
      MapEventLongClick(point: point, screenPoint: screenPoint);

  void _emitUserInput(
    Offset position,
    MapEventUserInput Function(Geographic point, Offset screenPoint) create,
  ) {
    final onEvent = widget.onEvent;
    if (onEvent == null) return;
    final point = widget.toLngLat(position);
    if (point == null) return;
    onEvent(create(point, position));
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
    _emitUserInput(
      details.localPosition,
      (point, screenPoint) =>
          MapEventDoubleClick(point: point, screenPoint: screenPoint),
    );
  }

  /// Zooms in on the second release of a double tap. A second tap that drags
  /// instead is a quick zoom, which the double tap recognizer rejects.
  void _onDoubleTap() {
    final position = _doubleTapPosition;
    _doubleTapPosition = null;
    if (position == null || !_gestures.zoom) return;
    _camera.zoomBy(1, position, duration: _doubleTapZoomDuration);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!_gestures.zoom) return;
    final double levels;
    switch (event) {
      case PointerScrollEvent(:final scrollDelta):
        final scale = MapGestureDetector.wheelPixelScale(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
          devicePixelRatio: View.of(context).devicePixelRatio,
        );
        levels = -scrollDelta.dy * scale * _wheelZoomRate;
      // A trackpad pinch where the platform reports it as a signal, as on
      // the web.
      case PointerScaleEvent(:final scale) when scale > 0:
        levels = log(scale) / ln2;
      default:
        return;
    }
    if (levels == 0 || !levels.isFinite) return;
    _camera.zoomBy(levels, event.localPosition);
  }

  void _onPointerDown(PointerDownEvent event) {
    // Rotate and tilt with the right button or Ctrl and the left button, as in
    // MapLibre GL JS.
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kSecondaryMouseButton != 0 ||
            (event.buttons & kPrimaryMouseButton != 0 &&
                HardwareKeyboard.instance.isControlPressed)) &&
        (_gestures.rotate || _gestures.pitch)) {
      _secondaryPointer = event.pointer;
      _beginGesture();
    }
    if (event.kind != PointerDeviceKind.touch) return;

    _touchPointers.add(event.pointer);
    _shovePosition[event.pointer] = event.localPosition;
    if (_touchPointers.length > 1) {
      // A second finger makes it a pinch or tilt, not a tap or a quick zoom.
      _touchDownPosition = null;
      _stopQuickZoom();
      _startShove();
      return;
    }
    _touchDownPosition = event.localPosition;
    final lastTime = _lastTapUpTime;
    final lastPosition = _lastTapUpPosition;
    if (_gestures.zoom &&
        lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime <= kDoubleTapTimeout &&
        (event.localPosition - lastPosition).distance <= kDoubleTapSlop) {
      _quickZoomPointer = event.pointer;
      _quickZoomAnchor = event.localPosition;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _quickZoomPointer) {
      _onQuickZoomMove(event);
      return;
    }
    if (_shovePosition.containsKey(event.pointer)) {
      _shovePosition[event.pointer] = event.localPosition;
      if (_shoveStart.containsKey(event.pointer)) _onShoveMove(event);
    }
    if (event.pointer != _secondaryPointer) return;
    final gestures = _gestures;
    final center = context.size?.center(Offset.zero);
    // Dragging right raises the bearing below the center and lowers it above,
    // so the map follows the pointer around the center like a wheel.
    var bearing = event.delta.dx * _rotateDegreesPerPixel;
    if (center != null && event.localPosition.dy < center.dy) {
      bearing = -bearing;
    }
    _camera.gestureUpdate(
      GestureCameraUpdate(
        rotateBy: gestures.rotate ? bearing : 0,
        // Dragging up tilts further.
        pitchBy: gestures.pitch ? -event.delta.dy * _pitchDegreesPerPixel : 0,
        around: center,
      ),
    );
  }

  void _onPointerEnd(PointerEvent event) {
    _shovePosition.remove(event.pointer);
    if (_shoveStart.containsKey(event.pointer)) _stopShove();
    if (_touchPointers.remove(event.pointer)) _onTouchEnd(event);
    if (event.pointer != _secondaryPointer) return;
    _secondaryPointer = null;
    _endGesture();
  }

  void _onTouchEnd(PointerEvent event) {
    final down = _touchDownPosition;
    final tapped =
        event is PointerUpEvent &&
        event.pointer != _quickZoomPointer &&
        down != null &&
        (event.localPosition - down).distance <= kTouchSlop;
    // A tap arms a quick zoom for the next touch. The second tap of a double
    // tap does not, so a third tap starts afresh.
    _lastTapUpTime = tapped ? event.timeStamp : null;
    _lastTapUpPosition = tapped ? event.localPosition : null;
    _touchDownPosition = null;
    if (event.pointer == _quickZoomPointer) _stopQuickZoom();
  }

  /// Zooms by the vertical drag of a double tap's second touch: down zooms
  /// in and up zooms out, around where that touch went down.
  void _onQuickZoomMove(PointerMoveEvent event) {
    final anchor = _quickZoomAnchor!;
    if (!_quickZooming) {
      if ((event.localPosition - anchor).distance <= kTouchSlop) return;
      _quickZooming = true;
      _doubleTapPosition = null;
      _beginGesture();
    }
    if (event.delta.dy == 0) return;
    _camera.gestureUpdate(
      GestureCameraUpdate(
        zoomBy: event.delta.dy / _quickZoomPixelsPerLevel,
        around: anchor,
      ),
    );
  }

  void _stopQuickZoom() {
    final zoomed = _quickZooming;
    _quickZoomPointer = null;
    _quickZoomAnchor = null;
    _quickZooming = false;
    if (zoomed) _endGesture();
  }

  /// Watches a two-finger touch for a tilt, as long as exactly two fingers
  /// are down.
  void _startShove() {
    _stopShove();
    if (_touchPointers.length != 2 || !_gestures.pitch) return;
    for (final pointer in _touchPointers) {
      _shoveStart[pointer] = _shovePosition[pointer]!;
    }
  }

  /// Tilts while two fingers side by side move vertically together: up tilts
  /// further, down back toward straight down, as on MapLibre Android.
  void _onShoveMove(PointerMoveEvent event) {
    if (_shoveRejected) return;
    if (!_shoving) {
      final [a, b] = _shoveStart.keys.toList();
      final moveA = _shovePosition[a]! - _shoveStart[a]!;
      final moveB = _shovePosition[b]! - _shoveStart[b]!;
      final between = _shovePosition[a]! - _shovePosition[b]!;
      final vertical =
          moveA.dy.sign == moveB.dy.sign &&
          moveA.dy.abs() > moveA.dx.abs() &&
          moveB.dy.abs() > moveB.dx.abs();
      final sideBySide = between.dy.abs() < between.dx.abs();
      if (vertical &&
          sideBySide &&
          moveA.dy.abs() >= _shoveSlop &&
          moveB.dy.abs() >= _shoveSlop) {
        _shoving = true;
        _beginGesture();
      } else if (!vertical ||
          !sideBySide ||
          moveA.distance > kTouchSlop * 2 ||
          moveB.distance > kTouchSlop * 2) {
        // Moving apart, around, or sideways: a pinch or rotation.
        _shoveRejected =
            moveA.distance > _shoveSlop || moveB.distance > _shoveSlop;
        return;
      } else {
        return;
      }
    }
    if (event.delta.dy == 0) return;
    // Each finger's move counts half, so both together tilt by their mean.
    _camera.gestureUpdate(
      GestureCameraUpdate(pitchBy: -event.delta.dy / 2 * _shoveDegreesPerPixel),
    );
  }

  void _stopShove() {
    final tilted = _shoving;
    _shoveStart.clear();
    _shoving = false;
    _shoveRejected = false;
    if (tilted) _endGesture();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1;
    _lastRotation = 0;
    _twist = 0;
    _turned = 0;
    _rotating = false;
    _panFromTouchDown =
        details.pointerCount == 1 &&
            _gestures.effectivePanPhysics.followsFromTouchDown
        ? _touchDownPosition
        : null;
    _beginGesture();
  }

  /// The radians the map turns by for a recognizer [rotation]: none until the
  /// fingers' twist passes [_rotateSlop], then what they turn from there on.
  ///
  /// The recognizer's rotation is a difference of two angles, each in
  /// -pi..pi, so it sits a full turn off while the fingers' line crosses
  /// pointing left. The twist adds up its changes, each taken the short way
  /// round.
  double _rotationBy(double rotation) {
    final change = rotation - _lastRotation;
    _lastRotation = rotation;
    _twist += atan2(sin(change), cos(change));
    if (!_rotating) {
      if (_twist.abs() < _rotateSlop) return 0;
      _rotating = true;
      _turned = _rotateSlop * _twist.sign;
    }
    final turn = _twist - _turned;
    _turned = _twist;
    return turn;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final gestures = _gestures;
    final scale = details.scale / _lastScale;
    final rotation = gestures.rotate ? _rotationBy(details.rotation) : 0.0;
    _lastScale = details.scale;
    final panFromTouchDown = _panFromTouchDown;
    _panFromTouchDown = null;
    // A quick zoom, tilt, or mouse rotation drives the camera while its
    // pointers also reach the scale recognizer.
    if (_quickZooming || _shoving || _secondaryPointer != null) return;

    final focal = details.localFocalPoint;
    final panFrom = panFromTouchDown ?? focal - details.focalPointDelta;
    final pans = gestures.pan && panFrom != focal;
    final zooms = gestures.zoom && scale != 1 && scale.isFinite && scale > 0;
    final rotates = gestures.rotate && rotation != 0;
    _camera.gestureUpdate(
      GestureCameraUpdate(
        panFrom: pans ? panFrom : null,
        panTo: pans ? focal : null,
        zoomBy: zooms ? log(scale) / ln2 : 0,
        // A clockwise twist is a positive rotation in Flutter and turns the
        // map clockwise, which lowers the bearing.
        rotateBy: rotates ? -rotation * 180 / pi : 0,
        around: zooms || rotates ? focal : null,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Only a plain drag or pinch flings; the others drove the camera
    // themselves.
    final flings =
        _gestures.pan &&
        !_quickZooming &&
        !_shoving &&
        _secondaryPointer == null;
    _endGesture(velocity: flings ? details.velocity : Velocity.zero);
  }

  void _beginGesture() {
    if (_gestureActive) return;
    _gestureActive = true;
    _camera.gestureStart();
  }

  void _endGesture({Velocity velocity = Velocity.zero}) {
    if (!_gestureActive) return;
    _gestureActive = false;
    _camera.gestureEnd(velocity: velocity);
  }
}
