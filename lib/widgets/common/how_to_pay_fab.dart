import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';

/// Pill FAB: money icon + "Jinsi ya Kulipia" + play — shown after scroll-down
/// for non‑premium users (or after subscription ends).
class HowToPayFab extends StatefulWidget {
  const HowToPayFab({
    super.key,
    required this.visible,
  });

  final bool visible;

  @override
  State<HowToPayFab> createState() => _HowToPayFabState();
}

class _HowToPayFabState extends State<HowToPayFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: AnimatedBottomNav.contentBottomInset - 8,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          offset: widget.visible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: widget.visible ? 1 : 0,
            child: AnimatedBuilder(
              animation: _wave,
              builder: (context, child) {
                final t = _wave.value * 2 * math.pi;
                // Soft figure-eight drift + gentle bob — reads as waving in place.
                final dx = math.sin(t) * 5.5;
                final dy = math.sin(t * 2) * 4.2 + math.cos(t * 0.5) * 1.5;
                final tilt = math.sin(t) * 0.045;
                final glow = 0.42 + (math.sin(t) + 1) * 0.12;

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: tilt,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryIndigo
                                .withValues(alpha: glow * 0.55),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xFF22D3EE)
                                .withValues(alpha: glow * 0.35),
                            blurRadius: 18,
                            spreadRadius: -2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: InkWell(
                  onTap: () => openPaymentScreen(context),
                  borderRadius: BorderRadius.circular(32),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.premiumGradient,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFE566)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Color(0xFFFFE566),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Jinsi ya Kulipia',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.primaryIndigo,
                              size: 24,
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
