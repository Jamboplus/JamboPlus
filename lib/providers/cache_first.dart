import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prefer disk cache for instant UI, then refresh from network in the background.
Future<T> cacheFirstThenRefresh<T>({
  required Ref ref,
  required Future<T?> Function() loadCache,
  required Future<T> Function() fetchRemote,
  required Future<void> Function(T value) saveCache,
  required bool Function(T value) isUsable,
  required bool Function(T cached, T remote) didChange,
}) async {
  final cached = await loadCache();
  if (cached != null && isUsable(cached)) {
    // ignore: unawaited_futures
    (() async {
      try {
        final remote = await fetchRemote();
        await saveCache(remote);
        if (didChange(cached, remote)) {
          ref.invalidateSelf();
        }
      } catch (_) {
        // Keep serving cache.
      }
    })();
    return cached;
  }

  final remote = await fetchRemote();
  // ignore: unawaited_futures
  saveCache(remote);
  return remote;
}

bool listJsonChanged<T>(
  List<T> a,
  List<T> b,
  Map<String, dynamic> Function(T) toJson,
) {
  if (identical(a, b)) return false;
  if (a.length != b.length) return true;
  for (var i = 0; i < a.length; i++) {
    if (toJson(a[i]).toString() != toJson(b[i]).toString()) return true;
  }
  return false;
}
