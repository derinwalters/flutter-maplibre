part of 'map_state.dart';

/// `MLNDEMEncoding` — the raw enum values, because the header's `NS_ENUM` is not part
/// of the generated bindings. `MLNDEMEncodingMapbox = 0`, `MLNDEMEncodingTerrarium = 1`.
const int _mlnDemEncodingMapbox = 0;
const int _mlnDemEncodingTerrarium = 1;

/// The `MLNTileSourceOption` dictionary that
/// `-initWithIdentifier:tileURLTemplates:options:` expects.
///
/// Without it the native source silently falls back to its own defaults — zoom range
/// 0–22, tile size 512, no attribution — and everything the [Source] declared is
/// dropped. The zoom range is the one that changes what the map draws: a source whose
/// data stops at [maxZoom] is meant to OVERSCALE beyond it, and with the option missing
/// MapLibre keeps requesting deeper tiles that do not exist, so the layer can stop
/// drawing past its own maxzoom instead of stretching. The Android implementation has
/// always passed these through a `TileSet`, so this is also an iOS/Android divergence.
///
/// `MLNTileSourceOptionCoordinateBounds` is deliberately absent. It takes an `NSValue`
/// wrapping an `MLNCoordinateBounds`, and neither `+valueWithMLNCoordinateBounds:` nor
/// `+valueWithBytes:objCType:` is part of the generated bindings — adding it means
/// extending the ffigen config, which is a much larger change than this one. Bounds are
/// a request-count optimisation rather than a correctness property: a source without
/// them asks for tiles outside its extent and the server answers empty.
NSDictionary _tileSourceOptions({
  required double minZoom,
  required double maxZoom,
  int? tileSize,
  String? attribution,
  int? demEncoding,
}) {
  final options = NSMutableDictionary.new$()..init();
  void put(String key, ObjCObject value) =>
      options.setObject(value, forKey: NSCopying.as(key.toNSString()));

  // Passed as the doubles they are: MapLibre reads them with `integerValue`, so the
  // truncation is the platform's own and not a rounding policy invented here.
  //
  // Both or neither. MapLibre raises "MLNTileSourceOptionMinimumZoomLevel must be less
  // than MLNTileSourceOptionMaximumZoomLevel" when they cross, and a degenerate range is
  // legal on the Dart side today — it was simply being discarded. Sending it now would
  // turn a silently ignored value into a crash, so a range that cannot be expressed
  // falls back to the native defaults, exactly as before this change.
  if (minZoom < maxZoom) {
    put('MLNTileSourceOptionMinimumZoomLevel', minZoom.toNSNumber());
    put('MLNTileSourceOptionMaximumZoomLevel', maxZoom.toNSNumber());
  }
  if (tileSize != null) {
    put('MLNTileSourceOptionTileSize', tileSize.toNSNumber());
  }
  if (attribution != null) {
    put('MLNTileSourceOptionAttributionHTMLString', attribution.toNSString());
  }
  if (demEncoding != null) {
    put('MLNTileSourceOptionDEMEncoding', demEncoding.toNSNumber());
  }
  return options;
}

/// iOS specific implementation of the [StyleController].
class StyleControllerIos extends StyleController {
  StyleControllerIos._(this._ffiStyle);

  final MLNStyle _ffiStyle;

  @override
  Future<void> addImage(String id, Uint8List bytes) async {
    final image = UIImage.imageWithData(bytes.toNSData());
    if (image == null) return;
    _ffiStyle.setImage(image, forName: id.toNSString());
  }

  @override
  Future<void> addLayer(
    StyleLayer layer, {
    String? belowLayerId,
    String? aboveLayerId,
    int? atIndex,
  }) async {
    final ffiId = layer.id.toNSString();
    final prevStyleLayer = _ffiStyle.layerWithIdentifier(ffiId);
    if (prevStyleLayer != null) {
      throw Exception(
        'A Layer with the id "${layer.id}" already exists in the map style.',
      );
    }

    MLNStyleLayer? ffiLayer;
    switch (layer) {
      case BackgroundStyleLayer():
        ffiLayer = MLNBackgroundStyleLayer.new$()
          ..initWithIdentifier(ffiId)
          ..backgroundColor = NSExpression.expressionWithFormat(
            layer.color.toHexString().toNSString(),
          );
      case StyleLayerWithSource():
        final ffiSource = _ffiStyle.sourceWithIdentifier(
          layer.sourceId.toNSString(),
        );
        if (ffiSource == null) {
          throw Exception('Source "${layer.sourceId}" does not exist.');
        }
        switch (layer) {
          case FillStyleLayer():
            ffiLayer = MLNFillStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case CircleStyleLayer():
            ffiLayer = MLNCircleStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case FillExtrusionStyleLayer():
            ffiLayer = MLNFillExtrusionStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case HeatmapStyleLayer():
            ffiLayer = MLNHeatmapStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case HillshadeStyleLayer():
            ffiLayer = MLNHillshadeStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case LineStyleLayer():
            ffiLayer = MLNLineStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case RasterStyleLayer():
            ffiLayer = MLNRasterStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
          case SymbolStyleLayer():
            ffiLayer = MLNSymbolStyleLayer.new$()
              ..initWithIdentifier(ffiId, source: ffiSource);
        }
    }

    if (ffiLayer == null) {
      throw UnimplementedError(
        'The Layer is not supported: ${layer.runtimeType}',
      );
    }
    ffiLayer.minimumZoomLevel = layer.minZoom;
    ffiLayer.maximumZoomLevel = layer.maxZoom;
    ffiLayer.setProperties(layer.paint);
    ffiLayer.setProperties(layer.layout);
    if (layer case StyleLayerWithSource()) {
      if (layer.sourceLayerId case final sourceLayerId?) {
        final ffiVectorLayer = MLNVectorStyleLayer.as(ffiLayer);
        if (!MLNVectorStyleLayer.isA(ffiLayer)) {
          throw Exception(
            'sourceLayerId is only applicable for vector style layers.',
          );
        }
        ffiVectorLayer.sourceLayerIdentifier = sourceLayerId.toNSString();
      }
      if (layer.filter case final filter?) {
        if (!MLNVectorStyleLayer.isA(ffiLayer)) {
          throw Exception('filter is only applicable for vector style layers.');
        }
        final expression = jsonEncode(filter).toNSString();
        final ffiPredicate = Helpers.parsePredicateWithRaw(expression);
        final ffiVectorLayer = MLNVectorStyleLayer.as(ffiLayer);
        ffiVectorLayer.predicate = ffiPredicate;
      }
    }

    if (belowLayerId case final String id) {
      final belowLayer = _ffiStyle.layerWithIdentifier(id.toNSString());
      if (belowLayer == null) {
        throw Exception('Layer "$id" does not exist.');
      }
      _ffiStyle.insertLayer$2(ffiLayer, belowLayer: belowLayer);
    } else if (aboveLayerId case final String id) {
      final aboveLayer = _ffiStyle.layerWithIdentifier(id.toNSString());
      if (aboveLayer == null) {
        throw Exception('Layer "$id" does not exist.');
      }
      _ffiStyle.insertLayer(ffiLayer, aboveLayer: aboveLayer);
    } else if (atIndex case final int index) {
      _ffiStyle.insertLayer$1(ffiLayer, atIndex: index);
    } else {
      _ffiStyle.addLayer(ffiLayer);
    }
  }

  @override
  Future<void> addSource(Source source) async {
    final ffiId = source.id.toNSString();
    final prevSource = _ffiStyle.sourceWithIdentifier(ffiId);
    if (prevSource != null) {
      throw Exception(
        'A Source with the id "${source.id}" already exists in the map style.',
      );
    }

    final MLNSource ffiSource;
    switch (source) {
      case GeoJsonSource():
        final shapeSource = MLNShapeSource.new$();
        final ffiOptions = NSMutableDictionary.new$()..init();
        ffiOptions.setObject(
          source.tolerance.toNSNumber(),
          forKey: NSCopying.as(
            'MLNShapeSourceOptionSimplificationTolerance'.toNSString(),
          ),
        );
        if (source.data.startsWith('{')) {
          shapeSource.initWithIdentifier$3(
            ffiId,
            shape: MLNShape.shapeWithData(
              source.data.toNSDataUTF8()!,
              encoding: nsUTF8StringEncoding,
            ),
            options: ffiOptions,
          );
        } else {
          shapeSource.initWithIdentifier$1(
            ffiId,
            URL: source.data.toNSURL()!,
            options: ffiOptions,
          );
        }
        ffiSource = shapeSource;
      case RasterDemSource():
        final demSource = ffiSource = MLNRasterDEMSource.new$();
        if (source.url case final String url) {
          demSource.initWithIdentifier$2(
            ffiId,
            configurationURL: url.toNSURL()!,
            tileSize: source.tileSize.toDouble(),
          );
        } else {
          final ffiUrls = NSMutableArray.new$();
          for (final url in source.tiles ?? <String>[]) {
            ffiUrls.addObject(url.toNSString());
          }
          demSource.initWithIdentifier$3(
            ffiId,
            tileURLTemplates: ffiUrls,
            options: _tileSourceOptions(
              minZoom: source.minZoom,
              maxZoom: source.maxZoom,
              tileSize: source.tileSize,
              attribution: source.attribution,
              demEncoding: switch (source.encoding) {
                RasterDemTerrariumEncoding() => _mlnDemEncodingTerrarium,
                // `custom` has no iOS representation: MapLibre Native implements only
                // the two named encodings, so redFactor/greenFactor/blueFactor/baseShift
                // have nowhere to go. Falling back to Mapbox matches the native default
                // rather than inventing a decode the engine cannot perform.
                _ => _mlnDemEncodingMapbox,
              },
            ),
          );
        }
      case RasterSource():
        final rasterSource = ffiSource = MLNRasterTileSource.new$();
        if (source.url case final String url) {
          rasterSource.initWithIdentifier$2(
            ffiId,
            configurationURL: url.toNSURL()!,
            tileSize: source.tileSize.toDouble(),
          );
        } else {
          final ffiUrls = NSMutableArray.new$()..init();
          for (final url in source.tiles ?? <String>[]) {
            ffiUrls.addObject(url.toNSString());
          }
          rasterSource.initWithIdentifier$3(
            ffiId,
            tileURLTemplates: ffiUrls,
            options: _tileSourceOptions(
              minZoom: source.minZoom,
              maxZoom: source.maxZoom,
              tileSize: source.tileSize,
              attribution: source.attribution,
            ),
          );
        }
      case VectorSource():
        final vectorSource = ffiSource = MLNVectorTileSource.new$();
        if (source.url case final String url) {
          vectorSource.initWithIdentifier$2(
            ffiId,
            configurationURLString: url.toNSString(),
          );
        } else {
          final ffiUrls = NSMutableArray.new$()..init();
          for (final url in source.tiles ?? <String>[]) {
            ffiUrls.addObject(url.toNSString());
          }
          vectorSource.initWithIdentifier$3(
            ffiId,
            tileURLTemplates: ffiUrls,
            options: _tileSourceOptions(
              minZoom: source.minZoom,
              maxZoom: source.maxZoom,
              attribution: source.attribution,
            ),
          );
        }
      case ImageSource():
        final coordinates = Struct.create<MLNCoordinateQuad>()
          ..bottomLeft = source.coordinates.bottomLeft
              .toCLLocationCoordinate2D()
          ..bottomRight = source.coordinates.bottomRight
              .toCLLocationCoordinate2D()
          ..topLeft = source.coordinates.topLeft.toCLLocationCoordinate2D()
          ..topRight = source.coordinates.topRight.toCLLocationCoordinate2D();
        final imageSource = ffiSource = MLNImageSource.new$();
        imageSource.initWithIdentifier$1(
          ffiId,
          coordinateQuad: coordinates,
          URL: source.url.toNSURL()!,
        );
      case VideoSource():
        throw UnsupportedError('Video source is only supported on web.');
      default:
        throw UnimplementedError(
          'The Source is not supported: ${source.runtimeType}',
        );
    }
    _ffiStyle.addSource(ffiSource);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<List<String>> getAttributions() async => getAttributionsSync();

  @override
  List<String> getLayerIds() {
    final layers = _ffiStyle.layers.asDart().map(MLNStyleLayer.as);
    return layers.map((l) => l.identifier.toDartString()).toList();
  }

  @override
  Future<void> removeImage(String id) async {
    final ffiId = id.toNSString();
    _ffiStyle.removeImageForName(ffiId);
  }

  @override
  Future<void> removeLayer(String id) async {
    final ffiId = id.toNSString();
    final ffiLayer = _ffiStyle.layerWithIdentifier(ffiId);
    if (ffiLayer == null) return;
    _ffiStyle.removeLayer(ffiLayer);
  }

  @override
  Future<void> removeSource(String id) async {
    final ffiId = id.toNSString();
    final ffiSource = _ffiStyle.sourceWithIdentifier(ffiId);
    if (ffiSource == null) return;
    _ffiStyle.removeSource(ffiSource);
  }

  @override
  Future<void> updateGeoJsonSource({
    required String id,
    required String data,
  }) async {
    final source = _ffiStyle.sourceWithIdentifier(id.toNSString())!;
    final shapeSource = MLNShapeSource.as(source);
    shapeSource.shape = MLNShape.shapeWithData(
      data.toNSDataUTF8()!,
      encoding: 4, // utf-8
    );
  }

  List<MLNStyleLayer> _getLayers() => List<MLNStyleLayer>.from(
    _ffiStyle.layers.toDartList(convertOther: MLNStyleLayer.as),
  );

  @override
  void setProjection(MapProjection projection) {
    // no implementation needed, globe is not supported on web.
  }

  @override
  List<String> getAttributionsSync() {
    final attributions = <String>[];
    final sources = _ffiStyle.sources.allObjects.asDart();
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      if (!MLNTileSource.isA(source)) continue;
      final tileSource = MLNTileSource.as(source);
      final html = tileSource.attributionHTMLString;
      if (html == null) continue;
      attributions.add(html.toDartString());
    }
    return attributions;
  }
}
