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

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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

  void _openMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final meta = state.sectionMeta(AdminRepository.navItems);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.bg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AdminColors.surface,
              child: SafeArea(
                child: AdminSidebar(
                  activeId: state.section,
                  adminEmail: state.adminEmail,
                  onSelect: (id) {
                    state.setSection(id);
                    _closeDrawer();
                  },
                  onLogout: () {
                    _closeDrawer();
                    state.logout();
                  },
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            SafeArea(
              right: false,
              bottom: false,
              child: AdminSidebar(
                activeId: state.section,
                adminEmail: state.adminEmail,
                onSelect: state.setSection,
                onLogout: state.logout,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminHeader(
                  title: meta?.label ?? 'Dashibodi',
                  onMenu: wide ? null : _openMenu,
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
        ],
      ),
    );
  }
}
