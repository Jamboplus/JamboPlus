import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/admin_repository.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_sidebar.dart';
import 'carousel_screen.dart';
import 'channels_screen.dart';
import 'dashboard_screen.dart';
import 'player_config_screen.dart';
import 'pricing_screen.dart';
import 'users_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  Widget _screen(String id) {
    return switch (id) {
      'users' => const UsersScreen(),
      'carousel' => const CarouselScreen(),
      'channels' => const ChannelsScreen(),
      'pricing' => const PricingScreen(),
      'settings' => const PlayerConfigScreen(),
      _ => const DashboardScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final meta = state.sectionMeta(AdminRepository.navItems);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AdminColors.surface,
              child: AdminSidebar(
                activeId: state.section,
                adminEmail: state.adminEmail,
                onSelect: (id) {
                  state.setSection(id);
                  Navigator.pop(context);
                },
                onLogout: () {
                  Navigator.pop(context);
                  state.logout();
                },
              ),
            ),
      body: Row(
        children: [
          if (wide)
            AdminSidebar(
              activeId: state.section,
              adminEmail: state.adminEmail,
              onSelect: state.setSection,
              onLogout: state.logout,
            ),
          Expanded(
            child: Builder(
              builder: (innerContext) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminHeader(
                    title: meta?.label ?? 'Dashibodi',
                    onMenu: wide ? null : () => Scaffold.of(innerContext).openDrawer(),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(state.section),
                      child: _screen(state.section),
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
