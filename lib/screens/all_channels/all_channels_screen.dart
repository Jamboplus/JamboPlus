import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_strings.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/channel_provider.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/widgets/channels/channel_cards.dart';
import 'package:jamboplus/widgets/common/how_to_pay_fab.dart';
import 'package:jamboplus/widgets/common/search_filter_bar.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';

class AllChannelsScreen extends ConsumerStatefulWidget {
  const AllChannelsScreen({super.key});

  @override
  ConsumerState<AllChannelsScreen> createState() => _AllChannelsScreenState();
}

class _AllChannelsScreenState extends ConsumerState<AllChannelsScreen> {
  final _categoryController = ScrollController();
  var _showCategoryGuide = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guideCategories());
  }

  Future<void> _guideCategories() async {
    if (!_categoryController.hasClients ||
        _categoryController.position.maxScrollExtent <= 0) {
      if (mounted) setState(() => _showCategoryGuide = false);
      return;
    }

    await _categoryController.animateTo(
      _categoryController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_categoryController.hasClients) return;
    await _categoryController.animateTo(
      0,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _showCategoryGuide = false);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  static const _categories = [
    AppStrings.zote,
    AppStrings.bure,
    AppStrings.mpira,
    AppStrings.tamthilia,
    AppStrings.habari,
    AppStrings.katuni,
    AppStrings.trending,
  ];

  @override
  Widget build(BuildContext context) {
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
            child: Stack(
              children: [
                ListView.separated(
                  controller: _categoryController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                          color: isActive ? null : AppColors.surface,
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
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showCategoryGuide ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.only(left: 24, right: 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, AppColors.background],
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Telezesha',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.swipe_rounded,
                                color: AppColors.primaryCyan,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(rawChannelsProvider);
                ref.invalidate(channelsProvider);
                await Future.wait([
                  ref.read(channelsProvider.future),
                  ref.read(userProvider.notifier).refresh(heartbeat: true),
                ]);
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
        color: AppColors.surface,
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
