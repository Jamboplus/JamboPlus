import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/widgets/common/badges.dart';

class ChannelGridCard extends StatefulWidget {
  const ChannelGridCard({
    super.key,
    required this.channel,
    this.aspectRatio = 4 / 3,
    this.onTap,
  });

  final ChannelModel channel;
  final double aspectRatio;
  final VoidCallback? onTap;

  @override
  State<ChannelGridCard> createState() => _ChannelGridCardState();
}

class _ChannelGridCardState extends State<ChannelGridCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryIndigo.withValues(
                  alpha: _pressed ? 0.15 : 0.08,
                ),
                blurRadius: _pressed ? 20 : 12,
                offset: Offset(0, _pressed ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.channel.image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.primaryIndigo.withValues(alpha: 0.1),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  if (widget.channel.isLive)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: LiveBadge(compact: true),
                    ),
                  if (widget.channel.isPremium)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: PremiumBadge(compact: true),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CategoryBadge(category: widget.channel.category),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChannelHorizontalCard extends StatefulWidget {
  const ChannelHorizontalCard({
    super.key,
    required this.channel,
    this.width = 200,
    this.height = 140,
    this.onTap,
  });

  final ChannelModel channel;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  State<ChannelHorizontalCard> createState() => _ChannelHorizontalCardState();
}

class _ChannelHorizontalCardState extends State<ChannelHorizontalCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: widget.width,
          height: widget.height,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryIndigo.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.channel.image,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.primaryIndigo.withValues(alpha: 0.1),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.primaryIndigo.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
                if (widget.channel.isLive)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: LiveBadge(),
                  ),
                if (widget.channel.isPremium)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: PremiumBadge(),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CategoryBadge(category: widget.channel.category),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class ChannelListTile extends StatefulWidget {
  const ChannelListTile({
    super.key,
    required this.channel,
    this.onTap,
  });

  final ChannelModel channel;
  final VoidCallback? onTap;

  @override
  State<ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends State<ChannelListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryIndigo.withValues(
                    alpha: _pressed ? 0.12 : 0.06,
                  ),
                  blurRadius: _pressed ? 16 : 10,
                  offset: Offset(0, _pressed ? 6 : 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.channel.image,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.primaryIndigo.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.channel.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.channel.isLive) ...[
                            const SizedBox(width: 6),
                            const LiveBadge(compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.channel.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryIndigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primaryIndigo.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Bure section layout: pairs in rows, last odd item spans full width.
class BureChannelsGrid extends StatelessWidget {
  const BureChannelsGrid({
    super.key,
    required this.channels,
    this.onChannelTap,
  });

  final List<ChannelModel> channels;
  final void Function(ChannelModel)? onChannelTap;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    var i = 0;

    while (i < channels.length) {
      final remaining = channels.length - i;

      if (remaining == 1) {
        rows.add(_buildFull(context, channels[i]));
        i += 1;
      } else if (remaining == 3) {
        rows.add(_buildPair(context, channels[i], channels[i + 1]));
        rows.add(_buildFull(context, channels[i + 2]));
        i += 3;
      } else {
        rows.add(_buildPair(context, channels[i], channels[i + 1]));
        i += 2;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPair(BuildContext context, ChannelModel a, ChannelModel b) {
    return Row(
      children: [
        Expanded(
          child: ChannelGridCard(
            channel: a,
            onTap: () => onChannelTap?.call(a),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChannelGridCard(
            channel: b,
            onTap: () => onChannelTap?.call(b),
          ),
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context, ChannelModel channel) {
    return ChannelGridCard(
      channel: channel,
      aspectRatio: 16 / 7,
      onTap: () => onChannelTap?.call(channel),
    );
  }
}
