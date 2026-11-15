import 'package:maplibre_native/src/darwin/darwin_plugin.dart';
import 'package:maplibre_native/src/frame_target.dart';
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart';

/// Creates the target of an iOS or macOS map, which renders on its session's
/// core worker through Metal into a ring of BGRA8 IOSurfaces that the C
/// library allocates. Flutter samples the surface of the frame on screen
/// directly, without a copy. Its session draws CJK ideographs, kana and
/// Hangul with the fonts of [localIdeographFontFamily], when set.
FrameTarget createDarwinTarget(
  LogicalExtent extent, {
  String? localIdeographFontFamily,
}) => _IoSurfaceRingTarget(
  DarwinPlugin.createGpuTexture(),
  localIdeographFontFamily,
);

/// Flutter samples the surface of the frame on screen directly, so frames
/// are held until their slots are free.
final class _IoSurfaceRingTarget extends LibraryRingTarget {
  _IoSurfaceRingTarget(super.textureId, this._localIdeographFontFamily);

  final String? _localIdeographFontFamily;

  @override
  bool get holdsFrames => true;

  /// The C library creates the session's renderer, whose local glyph
  /// rasterizer reads its fonts, after the session attaches, so they are set
  /// just before.
  @override
  RenderSessionHandle attach(
    MapHandle map,
    LogicalExtent extent,
    Wake frameWake,
  ) {
    if (_localIdeographFontFamily case final fontFamily?) {
      DarwinPlugin.setLocalIdeographFonts(fontFamily);
    }
    return map.attachIoSurfaceRing(
      IoSurfaceRingDescriptor(
        logicalSize: logicalSize(extent),
        bufferCount: gpuSlotCount,
      ),
      attachOptions(frameWake),
    );
  }

  @override
  int presentFrame(AcquiredFrameHandle frame) => frame.withIoSurface((view) {
    DarwinPlugin.presentGpuTexture(
      textureId,
      ring: ring,
      slot: view.slot,
      surface: view.surface.address,
    );
    return view.slot;
  });

  @override
  bool slotInUse(int slot) => DarwinPlugin.slotInUse(textureId, slot);

  @override
  void disposeTexture() => DarwinPlugin.disposeTexture(textureId);
}
