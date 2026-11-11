import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre/maplibre.dart';

import 'shared/test_map.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runTests();
}

void runTests() {
  group('Paused rendering', () {
    /// Shows the map of [map] again, paused or not.
    Future<void> setPaused(TestMap map, {required bool paused}) async {
      await map.tester.pumpWidget(
        MapApp(
          options: offlineOptions(),
          onEvent: map.events.add,
          paused: paused,
        ),
      );
      await map.waitForEvent<MapEventRenderingChanged>(
        where: (event) => event.paused == paused,
      );
      expect(map.controller.isRenderingPaused, paused);
    }

    testWidgets('keeps the camera and shows changes on resume', (tester) async {
      final map = await pumpMap(tester);
      await setPaused(map, paused: true);

      // A frame demanded before the pause still renders the next update.
      await map.pumpFuture(
        map.controller.moveCamera(const CameraUpdate.position(zoom: 5)),
        reason: 'moving the camera of a paused map',
      );
      await tester.pump(const Duration(milliseconds: 500));

      await map.pumpFuture(
        map.controller.moveCamera(const CameraUpdate.position(zoom: 7)),
        reason: 'moving the camera of a paused map',
      );
      expect(map.controller.getCamera().zoom, closeTo(7, 1e-6));
      await tester.pump(const Duration(seconds: 1));
      expect(
        map.controller.camera!.zoom,
        isNot(closeTo(7, 1e-6)),
        reason: 'a paused map shows no new frame',
      );

      await setPaused(map, paused: false);
      await map.waitForFrame((camera) => (camera.zoom - 7).abs() < 1e-6);
      expect(map.style.layers.map((layer) => layer.id).toList(), [
        'background',
      ]);
    });

    testWidgets('ends a running camera animation at its target', (
      tester,
    ) async {
      final map = await pumpMap(tester);
      final animation = map.controller.animateCamera(
        const CameraUpdate.position(zoom: 2, bearing: 40),
        animation: const CameraAnimation.fly(duration: Duration(seconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await setPaused(map, paused: true);
      await map.pumpFuture(
        animation,
        reason: 'the animation never ended',
        timeout: const Duration(seconds: 5),
      );
      final camera = map.controller.getCamera();
      expect(camera.zoom, closeTo(2, 1e-6));
      expect(camera.bearing, closeTo(40, 1e-6));
    });

    testWidgets('pauses while an IndexedStack hides the map', (tester) async {
      final events = <MapEventRenderingChanged>[];
      Widget app(int index) => MaterialApp(
        home: IndexedStack(
          index: index,
          children: [
            MapLibreMap(
              options: offlineOptions(),
              onRenderingChanged: events.add,
            ),
            const SizedBox(),
          ],
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpWidget(app(1));
      await tester.pump();
      expect(events.map((e) => e.paused), [true]);
      await tester.pumpWidget(app(0));
      await tester.pump();
      expect(events.map((e) => e.paused), [true, false]);
    });

    /// A style of one background of [color].
    MapStyle background(String color) => MapStyle.json(
      jsonEncode({
        'version': 8,
        'sources': <String, Object>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': color},
          },
        ],
      }),
    );

    // A paused map releases its render session and texture, so it shows new
    // frames in a new texture when it resumes.
    testWidgets('shows a change made while paused on screen on resume', (
      tester,
    ) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(style: background('#ff0000')),
      );
      await map.waitForColorAtCenter('red', 0);
      Future<void> show(String color, {required bool paused}) =>
          tester.pumpWidget(
            MapApp(
              options: MapOptions(style: background(color)),
              onEvent: map.events.add,
              paused: paused,
            ),
          );
      await show('#ff0000', paused: true);
      await map.waitForEvent<MapEventRenderingChanged>(
        where: (event) => event.paused,
      );
      await show('#0000ff', paused: true);
      await tester.pump(const Duration(milliseconds: 500));
      await show('#0000ff', paused: false);
      await map.waitForColorAtCenter('blue', 2);
    });

    // So does every map while the app is hidden, which lets iOS freeze it.
    testWidgets('shows its frames on screen again after the app was hidden', (
      tester,
    ) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(style: background('#ff0000')),
      );
      await map.waitForColorAtCenter('red', 0);
      final binding = tester.binding;
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // Flutter draws no frame while the app is hidden, so a pump would never
      // return; the map settles asleep meanwhile.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await map.setOptions(MapOptions(style: background('#0000ff')));
      await map.waitForColorAtCenter('blue', 2);
    });
  }, skip: kIsWeb);
}
