import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/user_provider.dart';

class PremiumUpgradeCard extends ConsumerWidget {
  const PremiumUpgradeCard({
    super.key,
    this.onTap,
    this.compact = false,
  });

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final active = user.hasActiveSubscription;
    if (active) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 8 : 10,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.accentPurple.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'Fungua chaneli zote kwa bei nafuu',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}
