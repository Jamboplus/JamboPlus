import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

bool get isLinuxPlatform => Platform.isLinux;

Process? _activeSystemPlayer;

/// Stops paplay/aplay/ffplay started for payment voices.
Future<void> stopSystemVoicePlayback() async {
  final process = _activeSystemPlayer;
  _activeSystemPlayer = null;
  if (process == null) return;
  try {
    process.kill(ProcessSignal.sigterm);
  } catch (_) {
    try {
      process.kill();
    } catch (_) {}
  }
}

/// Stable cache filenames (no spaces for GStreamer paths).
const voiceCacheNames = <Object, String>{
  0: 'step_1.wav',
  1: 'step_2.wav',
  2: 'step_3.wav',
  3: 'step_4.wav',
  'wait': 'wait_confirmation.wav',
  'success': 'success.wav',
  'fail': 'fails.wav',
};

Future<File> writeVoiceCache(Object key, List<int> bytes) async {
  final name = voiceCacheNames[key] ?? 'voice_$key.wav';
  final dir = await getTemporaryDirectory();
  final cacheDir = Directory('${dir.path}/jamboplus_voices');
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  final file = File('${cacheDir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> playVoiceFromTempFile(
  AudioPlayer player,
  List<int> bytes,
  Object key, {
  required bool Function() isStale,
}) async {
  if (isStale()) return;

  final file = await writeVoiceCache(key, bytes);
  if (isStale()) return;

  if (await _playWithSystemPlayer(file.path, isStale)) return;
  if (isStale()) return;

  try {
    await player.stop();
    if (isStale()) return;
    await player.play(DeviceFileSource(file.path));
  } catch (e) {
    if (kDebugMode) {
      debugPrint('PaymentVoiceService: DeviceFileSource failed: $e');
    }
  }
}

Future<bool> _playWithSystemPlayer(
  String path,
  bool Function() isStale,
) async {
  final attempts = <List<String>>[
    ['paplay', path],
    ['aplay', path],
    ['ffplay', '-nodisp', '-autoexit', path],
  ];

  for (final args in attempts) {
    if (isStale()) return false;
    try {
      final process = await Process.start(args.first, args.sublist(1));
      _activeSystemPlayer = process;
      final exitCode = await process.exitCode;
      if (_activeSystemPlayer == process) {
        _activeSystemPlayer = null;
      }
      if (isStale()) return false;
      if (exitCode == 0) return true;
    } on ProcessException {
      continue;
    } catch (_) {
      continue;
    }
  }

  if (kDebugMode) {
    debugPrint(
      'PaymentVoiceService: paplay/aplay/ffplay could not play $path',
    );
  }
  return false;
}
