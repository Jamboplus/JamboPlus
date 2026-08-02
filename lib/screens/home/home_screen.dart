import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_strings.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/providers/carousel_provider.dart';
import 'package:jamboplus/providers/channel_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/widgets/channels/channel_cards.dart';
import 'package:jamboplus/widgets/common/premium_upgrade_card.dart';
import 'package:jamboplus/widgets/common/search_filter_bar.dart';
import 'package:jamboplus/widgets/common/section_header.dart';
import 'package:jamboplus/widgets/home/home_carousel.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';
import 'package:jamboplus/widgets/common/how_to_pay_fab.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);
    final query = ref.watch(homeSearchQueryProvider);
    final filter = ref.watch(homeFilterProvider);

    return SafeArea(
      child: ScrollAwareHowToPayScope(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(channelsProvider);
            ref.invalidate(carouselProvider);
            await Future.wait([
              ref.read(channelsProvider.future),
              ref.read(carouselProvider.future),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: HomeCarousel()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SearchFilterBar(
                    query: query,
                    filter: filter,
                    onQueryChanged: (v) =>
                        ref.read(homeSearchQueryProvider.notifier).state = v,
                    onFilterChanged: (v) =>
                        ref.read(homeFilterProvider.notifier).state = v,
                  ),
                ),
              ),
              channelsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Imeshindwa kupakia vituo.\nVuta chini kujaribu tena.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
                data: (channels) => _buildContent(context, ref, channels),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<ChannelModel> channels,
  ) {
    final query = ref.watch(homeSearchQueryProvider);
    final filter = ref.watch(homeFilterProvider);

    var displayChannels = channels;
    if (filter != AppStrings.zote) {
      displayChannels =
          displayChannels.where((c) => c.category == filter).toList();
    }
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      displayChannels = displayChannels
          .where(
            (c) =>
                c.name.toLowerCase().contains(lower) ||
                c.description.toLowerCase().contains(lower),
          )
          .toList();
    }

    if (filter != AppStrings.zote || query.isNotEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.only(
          top: 16,
          bottom: AnimatedBottomNav.contentBottomInset,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                return SectionHeader(
                  title: 'Matokeo (${displayChannels.length})',
                );
              }
              final channel = displayChannels[index - 1];
              return ChannelListTile(
                channel: channel,
                onTap: () => openChannel(context, ref, channel),
              );
            },
            childCount: displayChannels.isEmpty
                ? 2
                : displayChannels.length + 1,
          ),
        ),
      );
    }

    final bure = channelsByCategory(channels, AppStrings.bure);
    final mpira = channelsByCategory(channels, AppStrings.mpira);
    final tamthilia = channelsByCategory(channels, AppStrings.tamthilia);
    final habari = channelsByCategory(channels, AppStrings.habari);
    final katuni = channelsByCategory(channels, AppStrings.katuni);
    final wanyama = channelsByCategory(channels, AppStrings.wanyama);

    return SliverList(
      delegate: SliverChildListDelegate([
        SectionHeader(title: AppStrings.bure),
        BureChannelsGrid(
          channels: bure,
          onChannelTap: (c) => openChannel(context, ref, c),
        ),
        PremiumUpgradeCard(
          onTap: () => openPaymentScreen(context),
        ),
        SectionHeader(title: AppStrings.mpira),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 4),
            itemCount: mpira.length,
            itemBuilder: (context, index) => ChannelHorizontalCard(
              channel: mpira[index],
              width: 220,
              height: 150,
              onTap: () => openChannel(context, ref, mpira[index]),
            ),
          ),
        ),
        SectionHeader(title: AppStrings.tamthilia),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: tamthilia.length,
            itemBuilder: (context, index) => ChannelGridCard(
              channel: tamthilia[index],
              aspectRatio: 0.72,
              onTap: () => openChannel(context, ref, tamthilia[index]),
            ),
          ),
        ),
        SectionHeader(title: AppStrings.habari),
        ...habari.map(
          (c) => ChannelListTile(
            channel: c,
            onTap: () => openChannel(context, ref, c),
          ),
        ),
        SectionHeader(title: AppStrings.katuni),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 4),
            itemCount: katuni.length,
            itemBuilder: (context, index) => ChannelHorizontalCard(
              channel: katuni[index],
              width: 180,
              height: 130,
              onTap: () => openChannel(context, ref, katuni[index]),
            ),
          ),
        ),
        SectionHeader(title: AppStrings.wanyama),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 4),
            itemCount: wanyama.length,
            itemBuilder: (context, index) => ChannelHorizontalCard(
              channel: wanyama[index],
              width: 180,
              height: 130,
              onTap: () => openChannel(context, ref, wanyama[index]),
            ),
          ),
        ),
        const SizedBox(height: AnimatedBottomNav.contentBottomInset),
      ]),
    );
  }
}
