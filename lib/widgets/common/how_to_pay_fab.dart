import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';

/// Pill FAB: money icon + "Jinsi ya Kulipia" + play — shown after scroll-down
/// for non‑premium users (or after subscription ends).
class HowToPayFab extends StatelessWidget {
  const HowToPayFab({
    super.key,
    required this.visible,
  });

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: AnimatedBottomNav.contentBottomInset - 8,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: visible ? 1 : 0,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: InkWell(
                onTap: () => openPaymentScreen(context),
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.premiumGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryIndigo.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFFFFE566),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Jinsi ya Kulipia',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.primaryIndigo,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a scrollable; shows pay FAB only for free / expired users after scroll-down.
class ScrollAwareHowToPayScope extends ConsumerStatefulWidget {
  const ScrollAwareHowToPayScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<ScrollAwareHowToPayScope> createState() =>
      _ScrollAwareHowToPayScopeState();
}

class _ScrollAwareHowToPayScopeState
    extends ConsumerState<ScrollAwareHowToPayScope> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final show = n.metrics.pixels > 48;
    if (show != _scrolled) {
      setState(() => _scrolled = show);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = ref.watch(userProvider).hasActiveSubscription;
    final showFab = !subscribed && _scrolled;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        HowToPayFab(visible: showFab),
      ],
    );
  }
}
