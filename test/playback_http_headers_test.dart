import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamboplus/player/cdn_token_headers.dart';
import 'package:jamboplus/player/playback_http_headers.dart';

void main() {
  test('direct m3u8 gets player headers without page Origin', () {
    final headers = mergePlaybackHeaders('http://cdn.example/live/index.m3u8');
    expect(headers['User-Agent'], playbackChromeUserAgent);
    expect(headers['Accept'], '*/*');
    expect(headers.containsKey('Origin'), isFalse);
    expect(headers.containsKey('Referer'), isFalse);
    expect(headers.containsKey('Connection'), isTrue);
  });

  test('php gateway keeps Referer and the app request header', () {
    final headers = mergePlaybackHeaders('https://play.example/player.php?id=1');
    expect(headers['Origin'], 'https://play.example');
    expect(headers['Referer'], 'https://play.example/');
    expect(headers['X-Requested-With'], playbackAppPackageMarker);
  });

  test('admin Origin of another host is kept on a direct stream', () {
    final headers = mergePlaybackHeaders(
      'https://cdn.example/live/index.m3u8',
      {
        'Origin': 'https://tv.example',
        'Referer': 'https://tv.example/',
        'User-Agent': 'JamboPlus/1.0',
      },
    );
    expect(headers['Origin'], 'https://tv.example');
    expect(headers['Referer'], 'https://tv.example/');
    expect(headers['User-Agent'], 'JamboPlus/1.0');
    expect(headers['Accept'], '*/*');
  });

  test('admin Origin of the stream host is dropped for direct media', () {
    final headers = mergePlaybackHeaders(
      'https://cdn.example/live/index.m3u8',
      {'Origin': 'https://cdn.example', 'Referer': 'https://cdn.example/watch'},
    );
    expect(headers.containsKey('Origin'), isFalse);
    expect(headers.containsKey('Referer'), isFalse);
  });

  test('tokenized CDN uses the JWT url as Referer and Origin', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'url': 'https://azam.example/'})))
        .replaceAll('=', '');
    final header = base64Url.encode(utf8.encode('{}')).replaceAll('=', '');
    final url = 'https://cdn.example/tok_$header.$payload.sig/index.m3u8';
    expect(CdnTokenHeaders.isTokenizedCdnUrl(url), isTrue);
    expect(isGatewayPlaybackUrl(url), isFalse);
    final headers = playbackHttpHeaders(url);
    expect(headers['Origin'], 'https://azam.example');
    expect(headers['Referer'], 'https://azam.example/');
  });

  test('plain http iptv is direct media and https pages are gateways', () {
    expect(isDirectMediaUrl('http://10.0.0.8:8080/live/user/pass/1'), isTrue);
    expect(isGatewayPlaybackUrl('http://10.0.0.8:8080/live/user/pass/1'), isFalse);
    expect(isGatewayPlaybackUrl('https://embed.example/watch/123'), isTrue);
  });
}
