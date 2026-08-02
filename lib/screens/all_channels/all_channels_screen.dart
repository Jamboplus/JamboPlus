import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_strings.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/channel_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/widgets/channels/channel_cards.dart';
import 'package:jamboplus/widgets/common/how_to_pay_fab.dart';
import 'package:jamboplus/widgets/common/search_filter_bar.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';

class AllChannelsScreen extends ConsumerWidget {
  const AllChannelsScreen({super.key});

  static const _categories = [
    AppStrings.bure,
    AppStrings.mpira,
    AppStrings.tamthilia,
    AppStrings.habari,
    AppStrings.katuni,
    AppStrings.wanyama,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(allChannelsSearchProvider);
    final filter = ref.watch(allChannelsFilterProvider);
    final category = ref.watch(allChannelsCategoryProvider);
    final isGrid = ref.watch(isGridViewProvider);
    final channels = ref.watch(filteredAllChannelsProvider);

    return SafeArea(
      child: ScrollAwareHowToPayScope(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.chaneliZote,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                _ViewToggle(
                  isGrid: isGrid,
                  onChanged: (v) =>
                      ref.read(isGridViewProvider.notifier).state = v,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 12),
          SearchFilterBar(
            query: query,
            filter: filter,
            onQueryChanged: (v) =>
                ref.read(allChannelsSearchProvider.notifier).state = v,
            onFilterChanged: (v) =>
                ref.read(allChannelsFilterProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isActive = category == cat;
                return GestureDetector(
                  onTap: () => ref
                      .read(allChannelsCategoryProvider.notifier)
                      .state = cat,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      color: isActive ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryIndigo.withValues(
                            alpha: isActive ? 0.2 : 0.06,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isActive ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(channelsProvider);
              },
              child: channels.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Text(
                              AppStrings.hakunaChaneli,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    )
                  : isGrid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            AnimatedBottomNav.contentBottomInset,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: channels.length,
                          itemBuilder: (context, index) => ChannelGridCard(
                            channel: channels[index],
                            onTap: () => openChannel(context, ref, channels[index]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: AnimatedBottomNav.contentBottomInset,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: channels.length,
                          itemBuilder: (context, index) => ChannelListTile(
                            channel: channels[index],
                            onTap: () => openChannel(context, ref, channels[index]),
                          ),
                        ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isGrid, required this.onChanged});

  final bool isGrid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryIndigo.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.grid_view_rounded,
            isActive: isGrid,
            onTap: () => onChanged(true),
          ),
          _ToggleButton(
            icon: Icons.view_list_rounded,
            isActive: !isGrid,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}
