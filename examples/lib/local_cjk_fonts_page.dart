import 'package:maplibre/maplibre.dart';
import 'package:maplibre_example/utils/map_styles.dart';
import 'package:material_ui/material_ui.dart';

@immutable
class LocalCjkFontsPage extends StatelessWidget {
  const LocalCjkFontsPage({super.key});

  static const location = '/local-cjk-fonts';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local CJK Fonts')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              "The device's fonts draw the Japanese labels (iOS, macOS, web).",
            ),
          ),
          Expanded(
            child: MapLibreMap(
              options: MapOptions(
                style: MapStyles.openMapTilesLiberty.style,
                initCamera: const CameraUpdate.position(
                  center: Geographic(lon: 139.767, lat: 35.681),
                  zoom: 13,
                ),
                // The fonts belong to the process on iOS and macOS, so the
                // page has no switch to turn them off.
                localIdeographFontFamily: 'sans-serif',
              ),
              children: const [
                MapScalebar(),
                SourceAttribution(),
                MapCompass(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
