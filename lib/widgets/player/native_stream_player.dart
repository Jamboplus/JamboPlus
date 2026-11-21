import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jamboplus/models/playback_source.dart';
import 'package:jamboplus/player/playback_http_headers.dart';
import 'package:jamboplus/widgets/player/web_stream_player.dart';

/// Android ExoPlayer surface. Sends real HTTP headers and renders through a
/// Flutter texture so the picture stays sharp without WebView scratches.
class NativeStreamPlayer extends StatefulWidget {
  final PlaybackSource source;
  final WebStreamController controller;
  final StreamStateCallback onState;
  final ValueChanged<List<String>> onQualities;
  final ValueChanged<List<String>> onLanguages;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onError;

  const NativeStreamPlayer({
    super.key,
    required this.source,
    required this.controller,
    required this.onState,
    required this.onQualities,
    required this.onLanguages,
    required this.onQualityChanged,
    required this.onLanguageChanged,
    required this.onError,
  });

  @override
  State<NativeStreamPlayer> createState() => _NativeStreamPlayerState();
}

class _NativeStreamPlayerState extends State<NativeStreamPlayer> {
  static final _events = const EventChannel('jamboplus/native_player_events')
      .receiveBroadcastStream()
      .asBroadcastStream();

  StreamSubscription<dynamic>? _subscription;
  int? _textureId;
  double _aspect = 16 / 9;
  var _closed = false;
  late StreamStateCallback _onState = widget.onState;
  late ValueChanged<List<String>> _onQualities = widget.onQualities;
  late ValueChanged<List<String>> _onLanguages = widget.onLanguages;
  late ValueChanged<String> _onQualityChanged = widget.onQualityChanged;
  late ValueChanged<String> _onLanguageChanged = widget.onLanguageChanged;
  late ValueChanged<String> _onError = widget.onError;

  @override
  void initState() {
    super.initState();
    widget.controller.useNative = true;
    _subscription = _events.listen(_onEvent);
    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant NativeStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onState = widget.onState;
    _onQualities = widget.onQualities;
    _onLanguages = widget.onLanguages;
    _onQualityChanged = widget.onQualityChanged;
    _onLanguageChanged = widget.onLanguageChanged;
    _onError = widget.onError;
    widget.controller.useNative = true;
  }

  Future<void> _open() async {
    final headers = widget.source.headers.isNotEmpty
        ? widget.source.headers
        : mergePlaybackHeaders(widget.source.url);
    try {
      final id = await widget.controller.openNative(
        url: widget.source.url,
        headers: headers,
        drm: widget.source.drm.name,
        clearKey: widget.source.clearKey,
        licenseUrl: widget.source.licenseUrl,
      );
      if (!mounted || _closed) {
        if (id != null && id >= 0) {
          await widget.controller.disposeNative(id);
        }
        return;
      }
      if (id == null || id < 0) {
        _onError('Video haikuweza kuchezwa.');
        return;
      }
      setState(() => _textureId = id);
    } on PlatformException catch (error) {
      if (!mounted || _closed) return;
      _onError(error.message ?? 'Video haikuweza kuchezwa.');
    }
  }

  void _onEvent(dynamic raw) {
    if (_closed || raw is! Map) return;
    final event = Map<String, dynamic>.from(raw);
    switch (event['type']) {
      case 'state':
        _onState(
          playing: event['playing'] as bool?,
          buffering: event['buffering'] as bool?,
          position: (event['position'] as num?)?.toDouble(),
          duration: (event['duration'] as num?)?.toDouble(),
        );
      case 'tracks':
        final qualities = (event['qualities'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
        final languages = (event['languages'] as List<dynamic>? ?? const ['sw', 'en'])
            .map((item) => item.toString())
            .toList();
        if (qualities.isNotEmpty) _onQualities(qualities);
        if (languages.isNotEmpty) _onLanguages(languages);
        final quality = event['activeQuality'] as String?;
        final language = event['activeLanguage'] as String?;
        if (quality != null && quality.isNotEmpty) _onQualityChanged(quality);
        if (language != null && language.isNotEmpty) _onLanguageChanged(language);
      case 'videoSize':
        final width = (event['width'] as num?)?.toDouble() ?? 0;
        final height = (event['height'] as num?)?.toDouble() ?? 0;
        if (width > 0 && height > 0 && mounted) {
          setState(() => _aspect = width / height);
        }
      case 'error':
        _onError(event['message']?.toString() ?? 'Video haikuweza kuchezwa.');
    }
  }

  @override
  void dispose() {
    _closed = true;
    widget.controller.useNative = false;
    final id = _textureId;
    _textureId = null;
    unawaited(_subscription?.cancel());
    if (id != null) {
      unawaited(widget.controller.disposeNative(id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _textureId;
    return ColoredBox(
      color: Colors.black,
      child: id == null
          ? const SizedBox.expand()
          : Center(
              child: AspectRatio(
                aspectRatio: _aspect <= 0 ? 16 / 9 : _aspect,
                child: Texture(textureId: id),
              ),
            ),
    );
  }
}
