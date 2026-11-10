import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// The speed a fling starts at, in logical pixels per second.
///
/// A curve whose first control point is at the origin starts with the slope
/// of its second, d / c, times the fling's mean speed.
double _startSpeed(PanFling fling) {
  final curve = fling.curve;
  expect((curve.a, curve.b), (0, 0));
  final seconds = fling.duration.inMicroseconds / 1e6;
  return curve.d / curve.c * fling.offset.distance / seconds;
}

void main() {
  group('PanPhysics.web', () {
    const physics = PanPhysics.web();

    test('carries a flick on as MapLibre GL JS does', () {
      final fling = physics.fling(const Offset(3000, 0))!;
      expect(fling.offset.dx, closeTo(540, 1e-9));
      expect(fling.offset.dy, 0);
      expect(fling.duration, const Duration(milliseconds: 1200));
      expect(
        (fling.curve.a, fling.curve.b, fling.curve.c, fling.curve.d),
        (0, 0, 0.3, 1),
      );
      // It slows to half the release speed the moment the finger lifts.
      expect(_startSpeed(fling), closeTo(1500, 1e-6));
    });

    test('caps the carried speed at 1400 pixels per second', () {
      final fling = physics.fling(const Offset(0, -6000))!;
      const seconds = 1400 / 750;
      expect(fling.offset.dy, closeTo(-1400 * seconds / 2, 1e-6));
      expect(fling.duration.inMicroseconds, (seconds * 1e6).round());
    });

    test('leaves a release at rest where it is', () {
      expect(physics.fling(Offset.zero), isNull);
    });

    test('pans from where the drag was recognized', () {
      expect(physics.followsFromTouchDown, isFalse);
    });
  });

  group('PanPhysics.mobile', () {
    const physics = PanPhysics.mobile();

    test('carries a flick on as the MapLibre iOS SDK does', () {
      final fling = physics.fling(const Offset(1300, -400))!;
      expect(fling.offset.dx, closeTo(1300 * 0.998 / 4, 1e-9));
      expect(fling.offset.dy, closeTo(-400 * 0.998 / 4, 1e-9));
      expect(fling.duration, const Duration(milliseconds: 998));
      expect(
        (fling.curve.a, fling.curve.b, fling.curve.c, fling.curve.d),
        (0, 0, 0.25, 1),
      );
    });

    test('starts at the release speed', () {
      final fling = physics.fling(const Offset(1300, 0))!;
      expect(_startSpeed(fling), closeTo(1300, 1e-6));
    });

    test('a longer glide carries the map further', () {
      final fling = const PanPhysics.mobile(glide: Duration(seconds: 2))
          .fling(const Offset(1000, 0))!;
      expect(fling.offset.dx, closeTo(500, 1e-9));
      expect(fling.duration, const Duration(seconds: 2));
      expect(_startSpeed(fling), closeTo(1000, 1e-6));
    });

    test('leaves a release slower than 100 pixels per second', () {
      expect(physics.fling(const Offset(99, 0)), isNull);
      expect(physics.fling(const Offset(100, 0)), isNotNull);
    });

    test('pans from where the finger touched down', () {
      expect(physics.followsFromTouchDown, isTrue);
    });
  });

  group('PanPhysics.platform', () {
    for (final platform in TargetPlatform.values) {
      final mobile =
          platform == TargetPlatform.iOS || platform == TargetPlatform.android;
      test(
        'is the ${mobile ? 'mobile' : 'web'} physics on ${platform.name}',
        () {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          expect(
            PanPhysics.platform(),
            mobile ? const PanPhysics.mobile() : const PanPhysics.web(),
          );
        },
      );
    }
  });

  test('MapGestures tell their pan physics apart', () {
    expect(
      const MapGestures.all(),
      isNot(const MapGestures.all(panPhysics: PanPhysics.web())),
    );
    expect(
      const MapGestures.all(
        panPhysics: PanPhysics.mobile(glide: Duration(seconds: 1)),
      ),
      // Not const, so equal values are told apart from the same instance.
      // ignore: prefer_const_constructors
      MapGestures.all(
        // ignore: prefer_const_constructors
        panPhysics: PanPhysics.mobile(glide: Duration(milliseconds: 1000)),
      ),
    );
    expect(
      const MapGestures.all(panPhysics: PanPhysics.web()).effectivePanPhysics,
      const PanPhysics.web(),
    );
  });
}
