import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_native/src/darwin/bindings.g.dart';
import 'package:maplibre_native/src/engine.dart';
import 'package:maplibre_native/src/plugin_error.dart';

/// The maplibre_native iOS and macOS plugin, called through its C API in
/// `darwin/maplibre_native/Sources/maplibre_native/include/maplibre_native/maplibre_native_api.h`.
final class DarwinPlugin {
  DarwinPlugin._();

  static final _bindings = MaplibreNativeDarwinBindings.fromLookup(
    _symbolLookup(),
  );

  /// Looks the C API up in the table of `+[MaplibreNativePlugin symbols]`.
  ///
  /// The plugin may be linked statically into the app, whose release builds
  /// strip global symbols, so `DynamicLibrary.process()` can't find its
  /// functions. The Objective-C runtime finds the class by name regardless.
  static Pointer<T> Function<T extends NativeType>(String) _symbolLookup() {
    final process = DynamicLibrary.process();
    final getClass = process
        .lookupFunction<
          Pointer<Void> Function(Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Utf8>)
        >('objc_getClass');
    final registerName = process
        .lookupFunction<
          Pointer<Void> Function(Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Utf8>)
        >('sel_registerName');
    // objc_msgSend takes the signature of the method it calls.
    final sendSymbols = process
        .lookupFunction<
          Pointer<MaplibreNativeSymbol> Function(Pointer<Void>, Pointer<Void>),
          Pointer<MaplibreNativeSymbol> Function(Pointer<Void>, Pointer<Void>)
        >('objc_msgSend');

    final symbols = using((arena) {
      final pluginClass = getClass(
        'MaplibreNativePlugin'.toNativeUtf8(allocator: arena),
      );
      if (pluginClass == nullptr) {
        throw StateError('The maplibre_native plugin is not linked.');
      }
      final table = sendSymbols(
        pluginClass,
        registerName('symbols'.toNativeUtf8(allocator: arena)),
      );
      return {
        for (var i = 0; table[i].name != nullptr; i++)
          table[i].name.cast<Utf8>().toDartString(): table[i].address,
      };
    });
    return <T extends NativeType>(String name) {
      final address = symbols[name];
      if (address == null) {
        throw ArgumentError.value(name, 'name', 'Not in the plugin C API');
      }
      return address.cast<T>();
    };
  }

  /// Registers a zero-copy texture that shows a ring of IOSurfaces, which
  /// the C library allocates, and returns its Flutter texture id.
  static int createGpuTexture() => using((arena) {
    final error = arena<Char>(pluginErrorSize);
    final id = _bindings.maplibre_native_create_gpu_texture(
      engineId,
      error,
      pluginErrorSize,
    );
    if (id < 0) throw StateError(_message(error));
    return id;
  });

  /// Makes the finished frame in the IOSurfaceRef [surface], at [slot] of the
  /// ring [ring], the one Flutter shows next, without a copy. The frame stays
  /// acquired until [slotInUse] reports its slot free.
  static void presentGpuTexture(
    int textureId, {
    required int ring,
    required int slot,
    required int surface,
  }) => using((arena) {
    final error = arena<Char>(pluginErrorSize);
    if (!_bindings.maplibre_native_present_gpu_texture(
      engineId,
      textureId,
      ring,
      slot,
      Pointer.fromAddress(surface),
      error,
      pluginErrorSize,
    )) {
      throw StateError(_message(error));
    }
  });

  /// Whether Flutter may still sample [slot] of a texture.
  static bool slotInUse(int textureId, int slot) => _bindings
      .maplibre_native_gpu_texture_slot_in_use(engineId, textureId, slot);

  /// Unregisters a texture.
  static void disposeTexture(int textureId) =>
      _bindings.maplibre_native_dispose_texture(engineId, textureId);

  /// Has the render sessions that attach from now on draw CJK ideographs,
  /// kana and Hangul with the fonts of the CSS font-family list [fontFamily],
  /// see `MapOptions.localIdeographFontFamily`.
  static void setLocalIdeographFonts(String fontFamily) => using((arena) {
    final names = fontFamilyNames(fontFamily).join('\n');
    _bindings.maplibre_native_set_local_ideograph_fonts(
      names.toNativeUtf8(allocator: arena).cast(),
    );
  });

  static String _message(Pointer<Char> error) => pluginErrorMessage(error);
}

/// The font and family names of the CSS font-family list [fontFamily], in
/// order, without their quotes.
@visibleForTesting
List<String> fontFamilyNames(String fontFamily) {
  final names = <String>[];
  final name = StringBuffer();
  String? quote;
  void take() {
    final value = name.toString().trim();
    if (value.isNotEmpty) names.add(value);
    name.clear();
  }

  for (final char in fontFamily.split('')) {
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        name.write(char);
      }
    } else if (char == '"' || char == "'") {
      quote = char;
    } else if (char == ',') {
      take();
    } else {
      name.write(char);
    }
  }
  take();
  return names;
}
