import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

enum _DurationUnit { minutes, hours, days, weeks }

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final q = state.userQuery.toLowerCase();
    final list = state.users.where((u) {
      if (q.isEmpty) return true;
      final name = (u['name'] as String? ?? '').toLowerCase();
      final phone = u['phone'] as String? ?? '';
      final deviceId = u['deviceId'] as String? ?? '';
      return name.contains(q) || phone.contains(q) || deviceId.toLowerCase().contains(q);
    }).toList();

    return AdminPage(
      toolbar: [
        Expanded(
          child: SearchField(hint: 'Tafuta jina, simu, kifaa…', onChanged: state.setUserQuery),
        ),
        const SizedBox(width: 12),
        if (state.users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _wipeAllUsers(context),
              icon: const Icon(Icons.delete_sweep_rounded, color: AdminColors.danger, size: 18),
              label: Text(
                'Futa Zote',
                style: AdminTheme.body(12, color: AdminColors.danger, weight: FontWeight.w700),
              ),
            ),
          ),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => openUserEditor(context, isNew: true),
        ),
      ],
      child: list.isEmpty
          ? Center(
              child: Text(
                'Hakuna watumiaji',
                style: AdminTheme.body(13, color: AdminColors.textHint),
              ),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => _UserRow(user: list[i]),
            ),
    );
  }
}

Future<void> _wipeAllUsers(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AdminColors.surface,
      title: Text('Futa akaunti zote?', style: AdminTheme.heading(18)),
      content: Text(
        'Hii itafuta watumiaji wote kutoka server. '
        'Premium kwenye simu zao itaisha baada ya app kusasisha. '
        'Admin login haitaguswa.',
        style: AdminTheme.body(13, color: AdminColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Ghairi', style: AdminTheme.body(13, color: AdminColors.textHint)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Futa Zote', style: AdminTheme.body(13, color: AdminColors.danger, weight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final n = await context.read<AdminState>().removeAllUsers();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Akaunti $n zimefutwa'),
        backgroundColor: AdminColors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
    );
  }
}

bool _isRegistered(Map<String, dynamic> user) {
  if (user['isRegistered'] == true) return true;
  final phone = (user['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
  return phone.length >= 9;
}

String _userSubtitle(Map<String, dynamic> user) {
  if (_isRegistered(user)) {
    return user['phone'] as String? ?? '';
  }
  final deviceId = user['deviceId'] as String? ?? '';
  if (deviceId.isEmpty) return 'App pekee';
  final short = deviceId.length > 8 ? deviceId.substring(deviceId.length - 8) : deviceId;
  return 'App pekee · …$short';
}

bool _hasPremium(Map<String, dynamic> user) {
  if (!_isRegistered(user)) return false;
  if (user['packageType'] != 'premium') return false;
  final expiry = user['expiryDate'] as String?;
  if (expiry == null) return true;
  return !DateTime.parse(expiry).isBefore(DateTime.now());
}

String _remainingLabel(Map<String, dynamic> user) {
  final expiry = user['expiryDate'] as String?;
  if (expiry == null) return 'Premium';
  final until = DateTime.parse(expiry);
  final diff = until.difference(DateTime.now());
  if (diff.isNegative) return 'Imeisha';
  if (diff.inDays >= 1) return '${diff.inDays} siku';
  if (diff.inHours >= 1) return '${diff.inHours} saa';
  return '${diff.inMinutes} dakika';
}

Future<void> openUserEditor(
  BuildContext context, {
  required bool isNew,
  Map<String, dynamic>? user,
}) async {
  final name = TextEditingController(text: user?['name'] as String? ?? '');
  final phone = TextEditingController(text: user?['phone'] as String? ?? '');
  var packageType = user?['packageType'] as String? ?? 'free';
  final expiryCtrl = TextEditingController(
    text: user?['expiryDate'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(user!['expiryDate'] as String))
        : '',
  );
  var saving = false;
  String? formError;

  await showAdminSheet(
    context: context,
    title: isNew ? 'Mtumiaji mpya' : 'Hariri mtumiaji',
    child: StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminFieldLabel('Jina'),
          adminTextField(controller: name, hint: 'Amani Joseph'),
          const SizedBox(height: 14),
          adminFieldLabel('Simu'),
          adminTextField(controller: phone, hint: '0712345678', keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          adminFieldLabel('Kifurushi'),
          DropdownButtonFormField<String>(
            initialValue: packageType,
            dropdownColor: AdminColors.surfaceLight,
            style: AdminTheme.body(14, color: AdminColors.textPrimary),
            items: const [
              DropdownMenuItem(value: 'free', child: Text('Bure')),
              DropdownMenuItem(value: 'premium', child: Text('Premium')),
            ],
            onChanged: (v) => setLocal(() => packageType = v ?? packageType),
          ),
          const SizedBox(height: 14),
          adminFieldLabel('Tarehe ya mwisho (yyyy-MM-dd, hiari)'),
          adminTextField(controller: expiryCtrl, hint: '2026-12-31'),
          if (formError != null) adminFormError(formError!),
          adminSaveButton(
            label: isNew ? 'Ongeza' : 'Hifadhi',
            loading: saving,
            onTap: () async {
              if (name.text.trim().isEmpty) return;
              setLocal(() {
                saving = true;
                formError = null;
              });
              final body = <String, dynamic>{
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'packageType': packageType,
                'expiryDate': expiryCtrl.text.trim().isEmpty
                    ? null
                    : '${expiryCtrl.text.trim()}T00:00:00.000Z',
              };
              try {
                if (isNew) {
                  await context.read<AdminState>().addUser(body);
                } else {
                  await context.read<AdminState>().updateUserRecord(user!['id'] as String, body);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } on ApiException catch (e) {
                setLocal(() {
                  saving = false;
                  formError = e.message;
                });
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final premium = _hasPremium(user);
    final expiry = user['expiryDate'] as String?;
    final dateFmt = DateFormat.yMMMd();

    return AdminListTile(
      leading: CircleAvatar(
        backgroundColor: premium
            ? AdminColors.green.withValues(alpha: 0.25)
            : AdminColors.navyMid.withValues(alpha: 0.35),
        child: Icon(
          premium ? Icons.workspace_premium_rounded : Icons.person_rounded,
          color: premium ? AdminColors.green : Colors.white,
          size: 22,
        ),
      ),
      title: user['name'] as String? ?? '—',
      subtitle: _userSubtitle(user),
      badges: [
        if (!_isRegistered(user))
          const StatusBadge('App pekee', color: AdminColors.info),
        StatusBadge(
          premium ? _remainingLabel(user) : 'Bure',
          color: premium ? AdminColors.green : AdminColors.info,
        ),
        if (expiry != null)
          StatusBadge(
            'Mwisho ${dateFmt.format(DateTime.parse(expiry))}',
            color: AdminColors.textSecondary,
          ),
      ],
      actions: [
        _AccessBtn(user: user),
        IconButton(
          tooltip: 'Hariri',
          onPressed: () => openUserEditor(context, isNew: false, user: user),
          icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
        ),
        DeleteIconButton(
          onDelete: () => deleteWithConfirm(
            context,
            dialogTitle: 'Futa mtumiaji',
            itemName: user['name'] as String? ?? '',
            onDelete: () => context.read<AdminState>().removeUser(user['id'] as String),
          ),
        ),
      ],
    );
  }
}

class _AccessBtn extends StatelessWidget {
  const _AccessBtn({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final active = _hasPremium(user);
    final color = active ? AdminColors.green : AdminColors.info;
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _AccessSheet.show(context, user),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.verified_rounded : Icons.vpn_key_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                'Ufikiaji',
                style: AdminTheme.body(11, color: color, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessSheet extends StatefulWidget {
  const _AccessSheet({required this.user});

  final Map<String, dynamic> user;

  static Future<void> show(BuildContext context, Map<String, dynamic> user) {
    return showAdminSheet(
      context: context,
      title: 'Dhibiti Ufikiaji',
      child: _AccessSheet(user: user),
    );
  }

  @override
  State<_AccessSheet> createState() => _AccessSheetState();
}

class _AccessSheetState extends State<_AccessSheet> {
  int _amount = 1;
  _DurationUnit _unit = _DurationUnit.days;
  bool _busy = false;

  static const _presets = <(int, _DurationUnit, String, IconData)>[
    (30, _DurationUnit.minutes, '30 dakika', Icons.bolt_rounded),
    (1, _DurationUnit.hours, '1 saa', Icons.schedule_rounded),
    (6, _DurationUnit.hours, '6 masaa', Icons.schedule_rounded),
    (1, _DurationUnit.days, '1 siku', Icons.today_rounded),
    (7, _DurationUnit.days, '7 siku', Icons.date_range_rounded),
    (4, _DurationUnit.weeks, '4 wiki', Icons.calendar_month_rounded),
  ];

  String _unitLabel(_DurationUnit unit) {
    return switch (unit) {
      _DurationUnit.minutes => _amount == 1 ? 'dakika' : 'dakika',
      _DurationUnit.hours => _amount == 1 ? 'saa' : 'masaa',
      _DurationUnit.days => _amount == 1 ? 'siku' : 'siku',
      _DurationUnit.weeks => _amount == 1 ? 'wiki' : 'wiki',
    };
  }

  Future<void> _grant(int amount, _DurationUnit unit) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AdminState>().grantPremium(widget.user['id'] as String, amount, unit.name);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessSnackBar(context, 'Ufikiaji umetolewa kwa ${widget.user['name']}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: AdminTheme.body(13, color: Colors.white)),
          backgroundColor: AdminColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AdminState>().revokePremium(widget.user['id'] as String);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessSnackBar(context, 'Ufikiaji umeondolewa');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: AdminTheme.body(13, color: Colors.white)),
          backgroundColor: AdminColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final name = u['name'] as String? ?? '';
    final active = _hasPremium(u);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? [AdminColors.greenDark, AdminColors.green]
                  : [AdminColors.surfaceLight, AdminColors.navyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AdminTheme.body(18, color: Colors.white, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AdminTheme.body(15, color: Colors.white, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          active ? Icons.verified_rounded : Icons.lock_outline_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          active ? 'Inaendelea: ${_remainingLabel(u)}' : 'Hana ufikiaji sasa',
                          style: AdminTheme.body(
                            12,
                            color: Colors.white.withValues(alpha: 0.9),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ongeza haraka',
          style: AdminTheme.body(13, color: AdminColors.textSecondary, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            return Material(
              color: AdminColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _busy ? null : () => _grant(p.$1, p.$2),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.$4, color: AdminColors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        p.$3,
                        style: AdminTheme.body(12, color: AdminColors.textPrimary, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Text(
          'Kiasi maalum',
          style: AdminTheme.body(13, color: AdminColors.textSecondary, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AdminColors.surfaceLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: () => setState(() => _amount = (_amount - 1).clamp(1, 999)),
              ),
              Expanded(
                child: Text(
                  '$_amount',
                  textAlign: TextAlign.center,
                  style: AdminTheme.heading(20, color: AdminColors.textPrimary),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _amount = (_amount + 1).clamp(1, 999)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _DurationUnit.values.map((unit) {
            final selected = unit == _unit;
            return ChoiceChip(
              label: Text(_unitLabel(unit)),
              selected: selected,
              onSelected: (_) => setState(() => _unit = unit),
              showCheckmark: false,
              labelStyle: AdminTheme.body(
                12,
                color: selected ? Colors.white : AdminColors.textSecondary,
                weight: FontWeight.w700,
              ),
              selectedColor: AdminColors.green,
              backgroundColor: AdminColors.bg,
              side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: active && !_busy ? _revoke : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: Text('Ondoa Ufikiaji', style: AdminTheme.body(13, weight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.danger,
                  disabledForegroundColor: AdminColors.textHint,
                  side: BorderSide(
                    color: active ? AdminColors.danger : AdminColors.border.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: adminSaveButton(
                label: 'Toa Ufikiaji',
                loading: _busy,
                onTap: () => _grant(_amount, _unit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AdminColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
