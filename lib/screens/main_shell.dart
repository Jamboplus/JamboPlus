import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/providers/app_config_provider.dart';
import 'package:jamboplus/providers/now_playing_provider.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/screens/all_channels/all_channels_screen.dart';
import 'package:jamboplus/screens/home/home_screen.dart';
import 'package:jamboplus/screens/payment/payment_screen.dart';
import 'package:jamboplus/screens/player/player_screen.dart';
import 'package:jamboplus/screens/user/user_screen.dart';
import 'package:jamboplus/core/theme/app_theme.dart';
import 'package:jamboplus/widgets/navigation/animated_bottom_nav.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _liveTimer;
  int _tick = 0;
  bool _syncing = false;

  static const _screens = <Widget>[
    HomeScreen(),
    AllChannelsScreen(),
    UserScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // First live sync shortly after open, then every 12s for subscription.
    _liveTimer = Timer.periodic(const Duration(seconds: 12), (_) => _onLiveTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLiveTick(full: true));
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onLiveTick(full: true);
    }
  }

  Future<void> _onLiveTick({bool full = false}) async {
    if (!mounted || _syncing) return;
    _syncing = true;
    _tick += 1;
    try {
      // Full content refresh about once a minute; subscription every tick.
      final fullContent = full || _tick % 5 == 0;
      await liveSyncTick(ref, fullContent: fullContent);
    } catch (_) {
      // Keep UI; next tick retries.
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBottomNav(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                  // Opening Mtumiaji always pulls latest subscription.
                  if (index == 2) {
                    // ignore: unawaited_futures
                    ref.read(userProvider.notifier).refresh(heartbeat: true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openPaymentScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PaymentScreen()),
  );
}

/// Opens the Leotena-style player for [channel], or payment if premium-locked.
void openChannel(BuildContext context, WidgetRef ref, ChannelModel channel) {
  final user = ref.read(userProvider);
  if (channel.isPremium && !user.hasActiveSubscription) {
    openPaymentScreen(context);
    return;
  }
  if (channel.streamUrl.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hakuna stream kwa ${channel.name}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return;
  }
  ref.read(nowPlayingProvider.notifier).playChannel(channel);
  PlayerScreen.open(context);
}

void showChannelSnackBar(BuildContext context, String name) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Unafungua: $name'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
