import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

enum _DurationUnit { minutes, hours, days, weeks }

enum _UserFilter { all, premium, free, appOnly }

String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Normalize TZ phones so 07… / 255… / 7… all match each other.
Set<String> _phoneMatchKeys(String raw) {
  final digits = _digitsOnly(raw);
  if (digits.isEmpty) return {};
  final keys = <String>{digits};
  if (digits.startsWith('255') && digits.length == 12) {
    keys.add('0${digits.substring(3)}');
    keys.add(digits.substring(3));
  } else if (digits.startsWith('0') && digits.length == 10) {
    keys.add('255${digits.substring(1)}');
    keys.add(digits.substring(1));
  } else if (digits.length == 9 && RegExp(r'^[67]').hasMatch(digits)) {
    keys.add('0$digits');
    keys.add('255$digits');
  }
  return keys.where((k) => k.length >= 9).toSet();
}

bool _phonesMatch(String a, String b) {
  final left = _phoneMatchKeys(a);
  final right = _phoneMatchKeys(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left.intersection(right).isNotEmpty;
}

bool _userMatchesQuery(Map<String, dynamic> u, String q) {
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  final name = (u['name'] as String? ?? '').toLowerCase();
  final phone = u['phone'] as String? ?? '';
  final deviceId = (u['deviceId'] as String? ?? '').toLowerCase();
  final id = (u['id'] as String? ?? '').toLowerCase();
  if (name.contains(lower)) return true;
  if (deviceId.contains(lower)) return true;
  if (id.contains(lower)) return true;
  if (phone.toLowerCase().contains(lower)) return true;
  if (_phoneMatchKeys(q).isNotEmpty && _phonesMatch(phone, q)) return true;
  return false;
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  _UserFilter _filter = _UserFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final q = state.userQuery.trim();
    final all = state.users;
    final premiumN = all.where(_hasPremium).length;
    final appOnlyN = all.where((u) => !_isRegistered(u)).length;
    final freeN = all.length - premiumN;

    final list = all.where((u) {
      if (!_userMatchesQuery(u, q)) return false;
      return switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.premium => _hasPremium(u),
        _UserFilter.free => !_hasPremium(u),
        _UserFilter.appOnly => !_isRegistered(u),
      };
    }).toList();

    return AdminPage(
      toolbar: [
        Expanded(
          child: ExpandableSearchBar(
            hint: 'Tafuta jina, simu, au Fingerprint ID…',
            query: state.userQuery,
            onChanged: state.setUserQuery,
            collapsedActions: [
              AdminIconAction(
                icon: Icons.fingerprint_rounded,
                tooltip: 'Toa Premium kwa ID',
                color: AdminColors.info,
                onTap: () => openUpgradeByUniqueId(context),
              ),
              if (all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: PopupMenuButton<String>(
                    tooltip: 'Hatua zaidi',
                    color: AdminColors.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (v) {
                      if (v == 'wipe') _wipeAllUsers(context);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'wipe',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded, color: AdminColors.danger, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Futa watumiaji wote',
                              style: AdminTheme.body(13, color: AdminColors.danger, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.border.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: AdminColors.textPrimary),
                    ),
                  ),
                ),
            ],
            persistentActions: [
              AdminIconAction(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Ongeza mtumiaji',
                filled: true,
                onTap: () => openUserEditor(context, isNew: true),
              ),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserInsightRow(
            total: all.length,
            premium: premiumN,
            free: freeN,
            appOnly: appOnlyN,
          ),
          const SizedBox(height: 12),
          _UserFilterBar(
            selected: _filter,
            onSelect: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: list.isEmpty
                ? _UsersEmptyState(
                    hasUsers: all.isNotEmpty,
                    query: q,
                    onAdd: () => openUserEditor(context, isNew: true),
                    onClear: q.isEmpty
                        ? null
                        : () => state.setUserQuery(''),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _UserCard(user: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserInsightRow extends StatelessWidget {
  const _UserInsightRow({
    required this.total,
    required this.premium,
    required this.free,
    required this.appOnly,
  });

  final int total;
  final int premium;
  final int free;
  final int appOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _InsightChip(label: 'Wote', value: '$total', color: AdminColors.info)),
        const SizedBox(width: 8),
        Expanded(child: _InsightChip(label: 'Premium', value: '$premium', color: AdminColors.green)),
        const SizedBox(width: 8),
        Expanded(child: _InsightChip(label: 'Bure', value: '$free', color: AdminColors.warning)),
        const SizedBox(width: 8),
        Expanded(child: _InsightChip(label: 'App', value: '$appOnly', color: AdminColors.textSecondary)),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AdminTheme.heading(16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AdminTheme.body(10, color: AdminColors.textHint, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _UserFilterBar extends StatelessWidget {
  const _UserFilterBar({required this.selected, required this.onSelect});

  final _UserFilter selected;
  final ValueChanged<_UserFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = <(_UserFilter, String)>[
      (_UserFilter.all, 'Zote'),
      (_UserFilter.premium, 'Premium'),
      (_UserFilter.free, 'Bure'),
      (_UserFilter.appOnly, 'App pekee'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final on = item.$1 == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.$2),
              selected: on,
              onSelected: (_) => onSelect(item.$1),
              showCheckmark: false,
              labelStyle: AdminTheme.body(
                12,
                color: on ? Colors.white : AdminColors.textSecondary,
                weight: FontWeight.w800,
              ),
              selectedColor: AdminColors.green,
              backgroundColor: AdminColors.surface,
              side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState({
    required this.hasUsers,
    required this.query,
    required this.onAdd,
    this.onClear,
  });

  final bool hasUsers;
  final String query;
  final VoidCallback onAdd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 42,
              color: AdminColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? 'Hakuna matokeo ya "$query"'
                  : hasUsers
                      ? 'Hakuna watumiaji kwenye kichujio hiki'
                      : 'Hakuna watumiaji bado',
              textAlign: TextAlign.center,
              style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Jaribu jina, namba ya simu, au Fingerprint ID'
                  : 'Ongeza mtumiaji au toa Premium kwa ID',
              textAlign: TextAlign.center,
              style: AdminTheme.body(12, color: AdminColors.textHint),
            ),
            const SizedBox(height: 16),
            if (onClear != null)
              TextButton(onPressed: onClear, child: const Text('Futa utafutaji'))
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Ongeza mtumiaji'),
              ),
          ],
        ),
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
  final phone = user['phone'] as String? ?? '';
  final deviceId = user['deviceId'] as String? ?? '';
  final short = deviceId.length > 8
      ? '…${deviceId.substring(deviceId.length - 8)}'
      : deviceId;

  if (_isRegistered(user)) {
    if (short.isEmpty) return phone;
    return '$phone · FP $short';
  }
  if (deviceId.isEmpty) return 'App pekee';
  return 'App pekee · FP $short';
}

bool _hasPremium(Map<String, dynamic> user) {
  if (user['packageType'] != 'premium') return false;
  final until = parseAdminDate(user['expiryDate'] as String?);
  if (until == null) return true;
  return !until.isBefore(DateTime.now());
}

String _remainingLabel(Map<String, dynamic> user) {
  final until = parseAdminDate(user['expiryDate'] as String?);
  if (until == null) return 'Premium';
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
  final deviceCtrl = TextEditingController(text: user?['deviceId'] as String? ?? '');
  var packageType = user?['packageType'] as String? ?? 'free';
  final parsedExpiry = parseAdminDate(user?['expiryDate'] as String?);
  final expiryCtrl = TextEditingController(
    text: parsedExpiry != null ? DateFormat('yyyy-MM-dd').format(parsedExpiry) : '',
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
          adminFieldLabel('Simu (hiari ikiwa kuna device id)'),
          adminTextField(controller: phone, hint: '0712345678', keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          adminFieldLabel('Fingerprint ID (kitambulisho cha kifaa)'),
          adminTextField(
            controller: deviceCtrl,
            hint: 'Fingerprint ID kutoka skrini ya Mtumiaji',
          ),
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
              final phoneDigits = phone.text.replaceAll(RegExp(r'\D'), '');
              final deviceId = deviceCtrl.text.trim();
              if (phoneDigits.length < 9 && deviceId.length < 8) {
                setLocal(() {
                  formError = 'Weka simu sahihi au kitambulisho cha kifaa';
                });
                return;
              }
              setLocal(() {
                saving = true;
                formError = null;
              });
              final expiryRaw = expiryCtrl.text.trim();
              if (expiryRaw.isNotEmpty && toAdminExpiryIso(expiryRaw) == null) {
                setLocal(() {
                  formError = 'Tarehe si sahihi — tumia yyyy-MM-dd au dd/MM/yyyy';
                });
                return;
              }
              final body = <String, dynamic>{
                'name': name.text.trim(),
                'phone': phoneDigits,
                'deviceId': deviceId,
                'packageType': packageType,
                'expiryDate': toAdminExpiryIso(expiryRaw),
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

Future<void> openUpgradeByUniqueId(BuildContext context) async {
  await showAdminSheet(
    context: context,
    title: 'Toa Premium kwa ID',
    child: const _UpgradeByUniqueIdSheet(),
  );
}

class _UpgradeByUniqueIdSheet extends StatefulWidget {
  const _UpgradeByUniqueIdSheet();

  @override
  State<_UpgradeByUniqueIdSheet> createState() => _UpgradeByUniqueIdSheetState();
}

class _UpgradeByUniqueIdSheetState extends State<_UpgradeByUniqueIdSheet> {
  final _idCtrl = TextEditingController();
  int _amount = 7;
  _DurationUnit _unit = _DurationUnit.days;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _lastUser;

  static const _presets = <(int, _DurationUnit, String, IconData)>[
    (30, _DurationUnit.minutes, '30 dakika', Icons.bolt_rounded),
    (1, _DurationUnit.hours, '1 saa', Icons.schedule_rounded),
    (1, _DurationUnit.days, '1 siku', Icons.today_rounded),
    (7, _DurationUnit.days, '7 siku', Icons.date_range_rounded),
    (30, _DurationUnit.days, '30 siku', Icons.calendar_month_rounded),
  ];

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _grant(int amount, _DurationUnit unit) async {
    final raw = _idCtrl.text.trim();
    if (raw.length < 8) {
      setState(() => _error = 'Weka Fingerprint ID, simu, au ID ya mtumiaji');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await context.read<AdminState>().grantPremiumByIdentifier(
            raw,
            amount,
            unit.name,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastUser = updated;
        _amount = amount;
        _unit = unit;
      });
      showSuccessSnackBar(
        context,
        'Premium imetolewa: ${updated['name'] ?? 'Mtumiaji'}',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _revoke() async {
    final raw = _idCtrl.text.trim();
    if (raw.length < 8) {
      setState(() => _error = 'Weka Fingerprint ID, simu, au ID ya mtumiaji');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await context.read<AdminState>().revokePremiumByIdentifier(raw);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastUser = updated;
      });
      showSuccessSnackBar(context, 'Ufikiaji umeondolewa');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nakili Fingerprint ID kutoka skrini ya Mtumiaji kwenye app, '
          'au tumia namba ya simu / ID ya akaunti.',
          style: AdminTheme.body(12, color: AdminColors.textSecondary),
        ),
        const SizedBox(height: 14),
        adminFieldLabel('Fingerprint ID / Simu / User ID'),
        adminTextField(
          controller: _idCtrl,
          hint: 'mf. abc123… au 0712345678',
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 18),
        Text(
          'Kiasi maalum',
          style: AdminTheme.body(13, color: AdminColors.textSecondary, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _DurationUnit.values.map((unit) {
            final selected = unit == _unit;
            final label = switch (unit) {
              _DurationUnit.minutes => 'dakika',
              _DurationUnit.hours => 'saa',
              _DurationUnit.days => 'siku',
              _DurationUnit.weeks => 'wiki',
            };
            return ChoiceChip(
              label: Text(label),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          adminFormError(_error!),
        ],
        if (_lastUser != null) ...[
          const SizedBox(height: 12),
          Text(
            'Imesasishwa: ${_lastUser!['name'] ?? '—'} · '
            '${_remainingLabel(_lastUser!)}',
            style: AdminTheme.body(12, color: AdminColors.green, weight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _revoke,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: Text('Ondoa', style: AdminTheme.body(13, weight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.danger,
                  side: BorderSide(color: AdminColors.danger.withValues(alpha: 0.7)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: adminSaveButton(
                label: 'Toa Premium',
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final premium = _hasPremium(user);
    final expiryAt = parseAdminDate(user['expiryDate'] as String?);
    final dateFmt = DateFormat.yMMMd();
    final name = user['name'] as String? ?? '—';
    final phone = user['phone'] as String? ?? '';
    final deviceId = user['deviceId'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: premium
              ? AdminColors.green.withValues(alpha: 0.35)
              : AdminColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: premium
                    ? AdminColors.green.withValues(alpha: 0.22)
                    : AdminColors.navyMid.withValues(alpha: 0.45),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AdminTheme.body(
                    16,
                    color: premium ? AdminColors.green : Colors.white,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _userSubtitle(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTheme.body(12, color: AdminColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                premium ? _remainingLabel(user) : 'Bure',
                color: premium ? AdminColors.green : AdminColors.info,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!_isRegistered(user))
                const StatusBadge('App pekee', color: AdminColors.info),
              if (phone.isNotEmpty)
                _CopyChip(
                  icon: Icons.phone_rounded,
                  label: phone,
                  copyValue: phone,
                ),
              if (deviceId.isNotEmpty)
                _CopyChip(
                  icon: Icons.fingerprint_rounded,
                  label: deviceId.length > 12 ? 'FP …${deviceId.substring(deviceId.length - 8)}' : 'FP $deviceId',
                  copyValue: deviceId,
                ),
              if (expiryAt != null)
                StatusBadge(
                  'Mwisho ${dateFmt.format(expiryAt)}',
                  color: AdminColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _UserActionBtn(
                  label: 'Ufikiaji',
                  icon: premium ? Icons.verified_rounded : Icons.vpn_key_rounded,
                  color: premium ? AdminColors.green : AdminColors.info,
                  onTap: () => _AccessSheet.show(context, user),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UserActionBtn(
                  label: 'Hariri',
                  icon: Icons.edit_rounded,
                  color: AdminColors.textSecondary,
                  onTap: () => openUserEditor(context, isNew: false, user: user),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Futa',
                onPressed: () => deleteWithConfirm(
                  context,
                  dialogTitle: 'Futa mtumiaji',
                  itemName: name,
                  onDelete: () => context.read<AdminState>().removeUser(user['id'] as String),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AdminColors.danger.withValues(alpha: 0.12),
                  foregroundColor: AdminColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  const _CopyChip({
    required this.icon,
    required this.label,
    required this.copyValue,
  });

  final IconData icon;
  final String label;
  final String copyValue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.bg.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: copyValue));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imenakiliwa: $copyValue'),
              backgroundColor: AdminColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AdminColors.textSecondary),
              const SizedBox(width: 5),
              Text(label, style: AdminTheme.body(11, color: AdminColors.textSecondary, weight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 11, color: AdminColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserActionBtn extends StatelessWidget {
  const _UserActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: AdminTheme.body(12, color: color, weight: FontWeight.w800)),
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
                    Text(
                      _userSubtitle(u),
                      style: AdminTheme.body(
                        11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
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
