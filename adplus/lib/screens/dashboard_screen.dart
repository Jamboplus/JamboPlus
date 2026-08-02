import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/admin_api_config.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final contentBars = <(String, double)>[
      ('Watumiaji', state.userCount.toDouble()),
      ('Premium', state.premiumCount.toDouble()),
      ('Vituo', state.channelCount.toDouble()),
      ('Slaidi', state.carousel.length.toDouble()),
      ('Bei', state.pricing.length.toDouble()),
      ('Malipo', state.todayTransactions.toDouble()),
    ];

    return AdminPage(
      toolbar: [
        if (state.loadError != null)
          Expanded(
            child: Text(
              state.loadError!,
              style: AdminTheme.body(12, color: AdminColors.danger),
            ),
          )
        else
          const Spacer(),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.green),
            ),
          ),
        IconButton(
          tooltip: 'Onyesha upya',
          onPressed: state.loading ? null : () => state.refreshAll(),
          icon: const Icon(Icons.refresh_rounded, color: AdminColors.textSecondary),
        ),
      ],
      child: state.loadError != null && state.users.isEmpty
          ? _OfflinePanel(
              message: state.loadError!,
              apiUrl: AdminApiConfig.baseUrl,
              onRetry: () => state.refreshAll(),
            )
          : ListView(
        children: [
          _HeroBanner(
            users: state.userCount,
            premium: state.premiumCount,
            revenue: state.revenueLabel,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 820;
              if (wide) {
                return SizedBox(
                  height: 260,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _ContentChart(data: contentBars)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _QuickGrid()),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _ContentChart(data: contentBars),
                  const SizedBox(height: 16),
                  _QuickGrid(),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _KpiCard(
                    label: 'Watumiaji',
                    value: '${state.userCount}',
                    icon: Icons.people_rounded,
                    gradient: const [Color(0xFF1D4A82), Color(0xFF3A86C9)],
                  ),
                  _KpiCard(
                    label: 'Premium',
                    value: '${state.premiumCount}',
                    icon: Icons.workspace_premium_rounded,
                    gradient: const [Color(0xFF0A7D4A), Color(0xFF19B26B)],
                  ),
                  _KpiCard(
                    label: 'Vituo LIVE',
                    value: '${state.liveChannelCount}',
                    icon: Icons.live_tv_rounded,
                    gradient: const [Color(0xFF5B2A86), Color(0xFF9B59B6)],
                  ),
                  _KpiCard(
                    label: 'Malipo leo',
                    value: '${state.todayTransactions}',
                    icon: Icons.payments_rounded,
                    gradient: const [Color(0xFF0F2748), Color(0xFF1D4A82)],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({
    required this.message,
    required this.apiUrl,
    required this.onRetry,
  });

  final String message;
  final String apiUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final authError = message.toLowerCase().contains('token') ||
        message.toLowerCase().contains('unauthorized') ||
        message.toLowerCase().contains('invalid');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              authError ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
              size: 56,
              color: AdminColors.textHint.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              authError ? 'Tokeni imeisha' : 'Seva haijaunganishwa',
              style: AdminTheme.heading(20, color: AdminColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              authError
                  ? 'Ingia tena ili kuendelea.\n$message'
                  : '$message\n\n$apiUrl',
              textAlign: TextAlign.center,
              style: AdminTheme.body(13, color: AdminColors.textHint),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AdminColors.green),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                authError ? 'Jaribu tena / Ingia' : 'Jaribu tena',
                style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.users,
    required this.premium,
    required this.revenue,
  });

  final int users;
  final int premium;
  final String revenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A7D4A), Color(0xFF19B26B), Color(0xFF1D4A82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AdminColors.green.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JamboPlus Admin', style: AdminTheme.heading(26, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '$users watumiaji · $premium premium',
                  style: AdminTheme.body(14, color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Mapato leo', style: AdminTheme.body(11, color: Colors.white70)),
                Text(revenue, style: AdminTheme.heading(16, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentChart extends StatelessWidget {
  const _ContentChart({required this.data});

  final List<(String, double)> data;

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.2;
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].$2));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yaliyomo (sasa)',
            style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AdminColors.border.withValues(alpha: 0.25),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: AdminTheme.body(10, color: AdminColors.textHint),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        return Text(data[i].$1, style: AdminTheme.body(9, color: AdminColors.textHint));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AdminColors.green,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AdminColors.green,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminColors.green.withValues(alpha: 0.35),
                          AdminColors.green.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  static const _items = [
    ('Watumiaji', Icons.people_rounded, 'users', AdminColors.green),
    ('Bei', Icons.sell_rounded, 'pricing', AdminColors.info),
    ('Vituo', Icons.live_tv_rounded, 'channels', AdminColors.warning),
    ('Slaidi', Icons.view_carousel_rounded, 'carousel', Color(0xFF9B59B6)),
    ('Mipangilio', Icons.settings_rounded, 'settings', AdminColors.navyMid),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cols = 2;
          const crossSpacing = 10.0;
          const mainSpacing = 10.0;
          const headerHeight = 27.0;
          final rows = (_items.length + cols - 1) ~/ cols;
          final boundedHeight = constraints.maxHeight.isFinite;

          var aspectRatio = 1.5;
          if (boundedHeight) {
            final gridHeight = (constraints.maxHeight - headerHeight).clamp(1.0, double.infinity);
            final gridWidth = constraints.maxWidth;
            final cellWidth = (gridWidth - crossSpacing * (cols - 1)) / cols;
            final cellHeight = (gridHeight - mainSpacing * (rows - 1)) / rows;
            if (cellHeight > 0) {
              aspectRatio = cellWidth / cellHeight;
            }
          }

          final grid = GridView.count(
            crossAxisCount: cols,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: crossSpacing,
            childAspectRatio: aspectRatio,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: !boundedHeight,
            children: _items.map((item) {
              return Material(
                color: AdminColors.bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.read<AdminState>().setSection(item.$3),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$2, color: item.$4, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          item.$1,
                          style: AdminTheme.body(13, color: AdminColors.textPrimary, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Haraka',
                style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (boundedHeight) Expanded(child: grid) else grid,
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AdminTheme.heading(24, color: Colors.white)),
              Text(label, style: AdminTheme.body(12, color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ],
      ),
    );
  }
}
