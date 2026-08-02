import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/register_platform_plugins.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'state/admin_state.dart';
import 'theme/admin_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerPlatformPlugins();
  runApp(const JamboAdApp());
}

class JamboAdApp extends StatelessWidget {
  const JamboAdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminState(),
      child: MaterialApp(
        title: 'JamboAd',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.dark(),
        home: const _BootGate(),
      ),
    );
  }
}

class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminState>().tryRestoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    if (state.booting) {
      return const Scaffold(
        backgroundColor: AdminColors.bg,
        body: Center(child: CircularProgressIndicator(color: AdminColors.green)),
      );
    }
    return state.loggedIn ? const AdminShell() : const LoginScreen();
  }
}
