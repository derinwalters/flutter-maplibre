part of 'map_options.dart';

/// How the map follows a one-finger drag, and how far a flick carries it on
/// once the finger lifts.
///
/// [MapGestures.panPhysics] picks one. [PanPhysics.platform] is the default:
/// the mobile physics in iOS and Android apps, the web physics on the web
/// and on desktops.
///
/// {@category Basic}
@immutable
sealed class PanPhysics {
  const PanPhysics();

  /// The pan of MapLibre GL JS, which [WebPanPhysics] describes.
  const factory PanPhysics.web() = WebPanPhysics;

  /// The pan of the MapLibre iOS SDK, which [MobilePanPhysics] describes.
  const factory PanPhysics.mobile({Duration glide}) = MobilePanPhysics;

  /// [PanPhysics.mobile] in iOS and Android apps, [PanPhysics.web] on the web,
  /// a phone's browser included, and on desktops.
  factory PanPhysics.platform() =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)
      ? const PanPhysics.mobile()
      : const PanPhysics.web();

  /// Whether a drag moves the map from where the finger touched down.
  ///
  /// A drag is recognized only once the finger has moved some pixels, 18 to
  /// 36 on a touch screen. If this is false, the map moves from where the
  /// drag was recognized, and stays that far behind the finger.
  bool get followsFromTouchDown;

  /// The move that carries the map on after a pan is released at [velocity],
  /// in logical pixels per second, or null if the map stays where it is.
  PanFling? fling(Offset velocity);
}

/// The pan of MapLibre GL JS.
///
/// The map moves from where a drag was recognized. A flick carries on at
/// 0.3 of its release speed, at most 1400 pixels per second, slowing by 2500
/// pixels per second squared along an ease-out curve, so the map slows to
/// half the finger's speed the moment the finger lifts. A flick at 1000
/// pixels per second carries the map 60 pixels on, one at 3000 pixels per
/// second 540.
///
/// {@category Basic}
final class WebPanPhysics extends PanPhysics {
  /// The pan of MapLibre GL JS.
  const WebPanPhysics();

  static const _linearity = 0.3;
  static const _maxSpeed = 1400.0;
  static const _deceleration = 2500.0;

  @override
  bool get followsFromTouchDown => false;

  @override
  PanFling? fling(Offset velocity) {
    final speed = min(velocity.distance * _linearity, _maxSpeed);
    if (speed == 0 || !speed.isFinite) return null;
    final seconds = speed / (_deceleration * _linearity);
    return PanFling(
      offset: velocity / velocity.distance * (speed * seconds / 2),
      duration: Duration(microseconds: (seconds * 1e6).round()),
      curve: const Cubic(0, 0, 0.3, 1),
    );
  }

  @override
  bool operator ==(Object other) => other is WebPanPhysics;

  @override
  int get hashCode => (WebPanPhysics).hashCode;
}

/// The pan of the MapLibre iOS SDK.
///
/// The map stays under the finger from where it touched down. A flick
/// carries on at the speed the finger left it at and slows to rest over
/// [glide] along MapLibre's default ease-out curve, which starts at four
/// times its mean speed. So the map travels a quarter of [glide] times the
/// release speed: a flick at 1000 pixels per second carries it 250 pixels
/// on, one at 3000 pixels per second 750. A release slower than 100 pixels
/// per second does not carry on.
///
/// {@category Basic}
final class MobilePanPhysics extends PanPhysics {
  /// The pan of the MapLibre iOS SDK, whose glide lasts 0.998 seconds.
  const MobilePanPhysics({this.glide = const Duration(milliseconds: 998)});

  /// How long a flick takes to slow to rest. A longer glide carries the map
  /// further, from the same release speed.
  final Duration glide;

  static const _minSpeed = 100.0;

  // MapLibre's default camera ease.
  static const _curve = Cubic(0, 0, 0.25, 1);

  @override
  bool get followsFromTouchDown => true;

  @override
  PanFling? fling(Offset velocity) {
    final speed = velocity.distance;
    if (!speed.isFinite || speed < _minSpeed || glide <= Duration.zero) {
      return null;
    }
    final seconds = glide.inMicroseconds / Duration.microsecondsPerSecond;
    return PanFling(
      offset: velocity * (seconds * _curve.c),
      duration: glide,
      curve: _curve,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MobilePanPhysics && other.glide == glide;

  @override
  int get hashCode => glide.hashCode;
}

/// The move that carries a released pan on: the map content moves by
/// [offset] over [duration], easing along [curve].
@immutable
class PanFling {
  /// Creates the move that carries a released pan on.
  const PanFling({
    required this.offset,
    required this.duration,
    required this.curve,
  });

  /// How far the map content moves, in logical pixels.
  final Offset offset;

  /// How long the move takes.
  final Duration duration;

  /// How the move eases over [duration].
  final Cubic curve;

  @override
  String toString() => 'PanFling($offset over $duration, $curve)';
}
