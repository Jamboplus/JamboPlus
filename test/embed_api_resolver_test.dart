import 'package:flutter_test/flutter_test.dart';
import 'package:jamboplus/player/embed_api_resolver.dart';
import 'package:jamboplus/player/playback_http_headers.dart';

void main() {
  test('detects sokamax-style embed.php players', () {
    expect(
      EmbedApiResolver.isEmbedApiPlayer(
        'https://sokamax.live/embed.php?app=160&key=${'a' * 64}',
      ),
      isTrue,
    );
    expect(
      EmbedApiResolver.isEmbedApiPlayer(
        'https://cdn.example/live/eds/AzamSports5/DASH/AzamSports5.mpd?tok=1',
      ),
      isFalse,
    );
    expect(
      EmbedApiResolver.isEmbedApiPlayer('https://sokamax.live/embed.php?app=1'),
      isFalse,
    );
  });

  test('gateway headers include X-Requested-With app marker', () {
    final headers = mergePlaybackHeaders(
      'https://sokamax.live/embed.php?app=160&key=${'a' * 64}',
    );
    expect(headers['X-Requested-With'], playbackAppPackageMarker);
    expect(headers.containsKey('Referer'), isTrue);
  });
}
