import 'dart:async';

import 'package:maplibre_native_ffi/maplibre_native_ffi.dart';

typedef _CookieKey = ({String host, String path, String name});
typedef _Cookie = ({String value, DateTime expires});

/// The cookies of `NetworkCookies`, which every runtime carries as the rules
/// of its HTTP header transform, online and offline requests alike.
///
/// The C API takes the headers of the first rule whose URL glob matches a
/// request and no other, so each host and path gets one rule carrying every
/// cookie whose path covers it, the longest path first.
final class NetworkCookieRules {
  NetworkCookieRules._();

  static final _cookies = <_CookieKey, _Cookie>{};
  static final _runtimes = <RuntimeHandle>{};
  static Timer? _expiry;

  /// Sets or replaces a cookie, or removes it when [expires] has passed, on
  /// the next request of every runtime.
  static void set({
    required String host,
    required String path,
    required String name,
    required String value,
    required DateTime expires,
  }) {
    _cookies[(host: host, path: path, name: name)] = (
      value: value,
      expires: expires,
    );
    _push();
  }

  /// Gives [runtime] the cookies, now and whenever they change.
  static Future<void> attach(RuntimeHandle runtime) async {
    _runtimes.add(runtime);
    if (_cookies.isEmpty) return;
    await runtime.setHttpHeaderTransform(_transform());
  }

  static void _push() {
    _runtimes.removeWhere((runtime) => runtime.isClosed);
    final transform = _transform();
    for (final runtime in _runtimes) {
      unawaited(runtime.setHttpHeaderTransform(transform));
    }
  }

  /// Drops the expired cookies, schedules the next expiry, and builds the
  /// rules from what is left.
  static HttpHeaderTransform _transform() {
    final now = DateTime.now();
    _cookies.removeWhere((_, cookie) => !cookie.expires.isAfter(now));
    _expiry?.cancel();
    _expiry = null;
    if (_cookies.isNotEmpty) {
      final next = _cookies.values
          .map((cookie) => cookie.expires)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      _expiry = Timer(next.difference(now), _push);
    }

    final scopes = {
      for (final key in _cookies.keys) (key.host, key.path),
    }.toList()..sort((a, b) => b.$2.length.compareTo(a.$2.length));
    return HttpHeaderTransform(
      rules: [
        for (final (host, path) in scopes)
          HttpHeaderRule(
            flags: UrlMatchFlag.glob,
            url: 'https://${_escape(host)}${_escape(path)}**',
            headers: [
              HttpHeader(
                name: 'Cookie',
                value: [
                  for (final MapEntry(:key, :value) in _cookies.entries)
                    if (key.host == host && path.startsWith(key.path))
                      '${key.name}=${value.value}',
                ].join('; '),
              ),
            ],
          ),
      ],
    );
  }

  /// Escapes the glob's special characters, which then match literally.
  static String _escape(String text) =>
      text.replaceAllMapped(RegExp(r'[\\*?]'), (match) => '\\${match[0]}');
}
