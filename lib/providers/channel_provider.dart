import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_strings.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/providers/service_providers.dart';

final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  return ref.read(apiServiceProvider).fetchChannels();
});

final homeSearchQueryProvider = StateProvider<String>((ref) => '');

final homeFilterProvider = StateProvider<String>((ref) => AppStrings.zote);

final allChannelsSearchProvider = StateProvider<String>((ref) => '');

final allChannelsFilterProvider = StateProvider<String>((ref) => AppStrings.zote);

final allChannelsCategoryProvider = StateProvider<String>((ref) => AppStrings.bure);

final isGridViewProvider = StateProvider<bool>((ref) => true);

final filteredHomeChannelsProvider = Provider<List<ChannelModel>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final query = ref.watch(homeSearchQueryProvider);
  final filter = ref.watch(homeFilterProvider);

  return channelsAsync.when(
    data: (channels) => _filter(channels, query, filter),
    loading: () => const [],
    error: (_, __) => const [],
  );
});

final filteredAllChannelsProvider = Provider<List<ChannelModel>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final query = ref.watch(allChannelsSearchProvider);
  final filter = ref.watch(allChannelsFilterProvider);
  final category = ref.watch(allChannelsCategoryProvider);

  return channelsAsync.when(
    data: (channels) {
      var result = _filter(channels, query, filter);
      if (category != AppStrings.zote) {
        result = result.where((c) => c.category == category).toList();
      }
      return result;
    },
    loading: () => const [],
    error: (_, __) => const [],
  );
});

List<ChannelModel> channelsByCategory(
  List<ChannelModel> channels,
  String category,
) {
  return channels.where((c) => c.category == category).toList();
}

List<ChannelModel> _filter(
  List<ChannelModel> channels,
  String query,
  String filter,
) {
  var result = channels;
  if (filter != AppStrings.zote) {
    result = result.where((c) => c.category == filter).toList();
  }
  if (query.isNotEmpty) {
    final lower = query.toLowerCase();
    result = result
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.description.toLowerCase().contains(lower),
        )
        .toList();
  }
  return result;
}
