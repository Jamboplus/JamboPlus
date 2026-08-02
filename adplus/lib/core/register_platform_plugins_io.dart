import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

void registerPlatformPlugins() {
  if (kIsWeb) return;

  if (Platform.isLinux) {
    PathProviderLinux.registerWith();
    SharedPreferencesLinux.registerWith();
  } else if (Platform.isWindows) {
    PathProviderWindows.registerWith();
    SharedPreferencesWindows.registerWith();
  }
}
