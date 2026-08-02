import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/models/playback_source.dart';
import 'package:jamboplus/models/user_model.dart';
import 'package:jamboplus/providers/user_provider.dart';

final nowPlayingProvider =
    StateNotifierProvider<NowPlayingNotifier, PlaybackSource?>((ref) {
  return NowPlayingNotifier(ref);
});

class NowPlayingNotifier extends StateNotifier<PlaybackSource?> {
  NowPlayingNotifier(this._ref) : super(null);

  final Ref _ref;

  void play(PlaybackSource source) => state = source;

  /// Returns false when the channel is premium and the user is not subscribed.
  bool playChannel(ChannelModel channel) {
    final user = _ref.read(userProvider);
    if (channel.isPremium && !user.hasActiveSubscription) return false;
    state = PlaybackSource.fromChannel(channel);
    return true;
  }

  void clear() => state = null;
}

bool channelLocked(ChannelModel channel, UserModel user) =>
    channel.isPremium && !user.hasActiveSubscription;
