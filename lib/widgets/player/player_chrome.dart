import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/screens/player/player_theme.dart';

class GreenBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const GreenBadge(
    this.text, {
    super.key,
    this.color = PlayerColors.green,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(text, style: PlayerTheme.body(9.5, color: textColor, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class PremiumChannelBadge extends ConsumerWidget {
  const PremiumChannelBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paid = ref.watch(userProvider).hasActiveSubscription;
    if (paid) {
      return const GreenBadge('Imelipiwa', icon: Icons.verified_rounded);
    }
    return const GreenBadge('MALIPO');
  }
}

class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, this.color = PlayerColors.green, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
      child: ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.15).animate(_c),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class Equalizer extends StatefulWidget {
  final Color color;
  final double height;

  const Equalizer({super.key, this.color = PlayerColors.green, this.height = 16});

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with TickerProviderStateMixin {
  late final List<AnimationController> _cs = List.generate(
    3,
    (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true)
      ..value = i * 0.25,
  );

  @override
  void dispose() {
    for (final c in _cs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.2),
          child: AnimatedBuilder(
            animation: _cs[i],
            builder: (_, __) => Container(
              width: 3.2,
              height: widget.height * (0.35 + 0.65 * _cs[i].value),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ChannelArt extends StatelessWidget {
  final ChannelModel channel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const ChannelArt({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [PlayerColors.navy, PlayerColors.navyMid],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: channel.image.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
                child: Center(
                  child: Text(
                    channel.name.isEmpty
                        ? '?'
                        : channel.name.substring(0, channel.name.length.clamp(0, 2)).toUpperCase(),
                    style: PlayerTheme.body(16, color: Colors.white, weight: FontWeight.w800),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: channel.image,
                width: width,
                height: height,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 350),
                placeholder: (_, __) => DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
                errorWidget: (_, __, ___) => DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                  child: const Center(
                    child: Icon(Icons.tv_rounded, color: Colors.white70),
                  ),
                ),
              ),
      ),
    );
  }
}
