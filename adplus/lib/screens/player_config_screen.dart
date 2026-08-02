import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/confirm_delete.dart';

class PlayerConfigScreen extends StatefulWidget {
  const PlayerConfigScreen({super.key});

  @override
  State<PlayerConfigScreen> createState() => _PlayerConfigScreenState();
}

class _PlayerConfigScreenState extends State<PlayerConfigScreen> {
  final _origin = TextEditingController();
  final _referer = TextEditingController();
  final _userAgent = TextEditingController();
  final _refreshUrl = TextEditingController();
  final _streamUserId = TextEditingController();
  final _apiKey = TextEditingController();
  final _apiSecret = TextEditingController();

  String _player = 'exoplayer';
  String _drm = 'none';
  var _maintenance = false;
  var _secretVisible = false;
  var _saving = false;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final config = context.read<AdminState>().appConfig;
    if (config != null) {
      _bind(config);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _origin.dispose();
    _referer.dispose();
    _userAgent.dispose();
    _refreshUrl.dispose();
    _streamUserId.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    super.dispose();
  }

  void _bind(Map<String, dynamic> c) {
    _player = c['playerEngine'] as String? ?? 'exoplayer';
    _drm = c['drmType'] as String? ?? 'none';
    _maintenance = c['maintenanceMode'] == true;
    _origin.text = c['streamOrigin'] as String? ?? '';
    _referer.text = c['streamReferer'] as String? ?? '';
    _userAgent.text = c['userAgent'] as String? ?? '';
    _refreshUrl.text = c['tokenRefreshUrl'] as String? ?? '';
    _streamUserId.text = c['streamUserId'] as String? ?? '';
    _apiKey.text = c['appApiKey'] as String? ?? '';
    _apiSecret.text = c['appApiSecret'] as String? ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AdminState>().saveAppConfig({
        'playerEngine': _player,
        'drmType': _drm,
        'streamOrigin': _origin.text.trim(),
        'streamReferer': _referer.text.trim(),
        'userAgent': _userAgent.text.trim(),
        'tokenRefreshUrl': _refreshUrl.text.trim(),
        'streamUserId': _streamUserId.text.trim(),
        'appApiKey': _apiKey.text.trim(),
        'appApiSecret': _apiSecret.text.trim(),
        'maintenanceMode': _maintenance,
      });
      if (mounted) showSuccessSnackBar(context, 'Imehifadhiwa');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: AdminColors.green));
    }

    return AdminPage(
      toolbar: [
        Text(
          'Mipangilio ya app',
          style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700),
        ),
        const Spacer(),
      ],
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Player & DRM',
                  style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _player,
                  dropdownColor: AdminColors.surfaceLight,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Player'),
                  items: const [
                    DropdownMenuItem(value: 'exoplayer', child: Text('ExoPlayer')),
                    DropdownMenuItem(value: 'shaka', child: Text('Shaka')),
                    DropdownMenuItem(value: 'webview', child: Text('WebView')),
                  ],
                  onChanged: (v) => setState(() => _player = v ?? _player),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _drm,
                  dropdownColor: AdminColors.surfaceLight,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'DRM'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Hakuna')),
                    DropdownMenuItem(value: 'clearkey', child: Text('ClearKey')),
                    DropdownMenuItem(value: 'widevine', child: Text('Widevine')),
                  ],
                  onChanged: (v) => setState(() => _drm = v ?? _drm),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _origin,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Stream Origin'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referer,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Referer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userAgent,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'User-Agent'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _refreshUrl,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Token refresh URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _streamUserId,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Stream user ID'),
                ),
                adminSwitchTile(
                  title: 'Maintenance mode',
                  value: _maintenance,
                  onChanged: (v) => setState(() => _maintenance = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'App API (HMAC)',
                  style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Weka secret kwenye build ya JamboPlus: --dart-define=JAMBO_APP_SECRET=…',
                  style: AdminTheme.body(12, color: AdminColors.textHint),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'App API key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiSecret,
                  obscureText: !_secretVisible,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'App API secret',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_secretVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _secretVisible = !_secretVisible),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _apiSecret.text));
                            showSuccessSnackBar(context, 'Secret imenakiliwa');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Hifadhi', style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
