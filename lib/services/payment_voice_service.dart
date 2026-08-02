import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'payment_voice_io_stub.dart'
    if (dart.library.io) 'payment_voice_io.dart';

/// Single-channel payment voice playback (no overlapping clips).
class PaymentVoiceService {
  PaymentVoiceService() : _player = AudioPlayer();

  final AudioPlayer _player;
  int _playGeneration = 0;

  static const stepAssets = <Object, String>{
    0: 'assets/Voices/1.wav',
    1: 'assets/Voices/2.wav',
    2: 'assets/Voices/3.wav',
    3: 'assets/Voices/4.wav',
    'wait': 'assets/Voices/waits confirmation.wav',
    'success': 'assets/Voices/success.wav',
    'fail': 'assets/Voices/Fails.wav',
  };

  Future<void> play(Object key) async {
    final assetPath = stepAssets[key];
    if (assetPath == null) return;

    final token = ++_playGeneration;
    await _stopAllPlayback();
    if (token != _playGeneration) return;

    try {
      final byteData = await rootBundle.load(assetPath);
      if (token != _playGeneration) return;

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final isStale = () => token != _playGeneration;

      if (!kIsWeb && isLinuxPlatform) {
        await playVoiceFromTempFile(
          _player,
          bytes,
          key,
          isStale: isStale,
        );
        return;
      }

      await _player.stop();
      if (isStale()) return;

      await _player.play(
        BytesSource(bytes, mimeType: 'audio/wav'),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PaymentVoiceService: could not play $assetPath: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _stopAllPlayback() async {
    await stopSystemVoicePlayback();
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _playGeneration++;
    await _stopAllPlayback();
    await _player.dispose();
  }
}
