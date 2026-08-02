import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final plans = state.pricing;
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

    return AdminPage(
      toolbar: [
        Text('${plans.length} bei', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => openPricingEditor(context, isNew: true),
        ),
      ],
      child: plans.isEmpty
          ? Center(child: Text('Hakuna bei', style: AdminTheme.body(13, color: AdminColors.textHint)))
          : ListView.builder(
              itemCount: plans.length,
              itemBuilder: (_, i) {
                final p = plans[i];
                final enabled = p['enabled'] == true;
                final price = (p['price'] as num?)?.toDouble() ?? 0;
                return AdminListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currency.format(price).replaceAll('TZS ', ''),
                      style: AdminTheme.body(10, color: AdminColors.green, weight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  title: p['name'] as String? ?? '',
                  subtitle: '${p['durationDays']} siku',
                  badges: [
                    StatusBadge(enabled ? 'Hai' : 'Zimwa', color: enabled ? AdminColors.green : AdminColors.textHint),
                  ],
                  actions: [
                    IconButton(
                      tooltip: 'Hariri',
                      onPressed: () => openPricingEditor(context, isNew: false, plan: p),
                      icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
                    ),
                    Switch(
                      value: enabled,
                      activeThumbColor: AdminColors.green,
                      onChanged: (v) => runWithErrorSnackBar(
                        context,
                        () => context.read<AdminState>().togglePricingEnabled(p['id'] as String, v),
                      ),
                    ),
                    DeleteIconButton(
                      onDelete: () => deleteWithConfirm(
                        context,
                        dialogTitle: 'Futa bei',
                        itemName: p['name'] as String? ?? '',
                        onDelete: () => context.read<AdminState>().removePricing(p['id'] as String),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

Future<void> openPricingEditor(
  BuildContext context, {
  required bool isNew,
  Map<String, dynamic>? plan,
}) async {
  final name = TextEditingController(text: plan?['name'] as String? ?? '');
  final price = TextEditingController(text: '${plan?['price'] ?? ''}');
  final days = TextEditingController(text: '${plan?['durationDays'] ?? 30}');
  final original = TextEditingController(text: '${plan?['originalPrice'] ?? plan?['price'] ?? ''}');
  var enabled = plan?['enabled'] != false;
  var saving = false;
  String? formError;

  await showAdminSheet(
    context: context,
    title: isNew ? 'Bei mpya' : 'Hariri bei',
    child: StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminFieldLabel('Jina'),
          adminTextField(controller: name, hint: 'Mwezi 1'),
          const SizedBox(height: 14),
          adminFieldLabel('Bei (TSh)'),
          adminTextField(controller: price, keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          adminFieldLabel('Bei ya awali'),
          adminTextField(controller: original, keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          adminFieldLabel('Siku'),
          adminTextField(controller: days, keyboardType: TextInputType.number),
          adminSwitchTile(
            title: 'Hai',
            value: enabled,
            onChanged: (v) => setLocal(() => enabled = v),
          ),
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
              final body = {
                'name': name.text.trim(),
                'price': double.tryParse(price.text.trim()) ?? 0,
                'originalPrice': double.tryParse(original.text.trim()) ?? double.tryParse(price.text.trim()) ?? 0,
                'durationDays': int.tryParse(days.text.trim()) ?? 30,
                'enabled': enabled,
                if (isNew) 'sortOrder': context.read<AdminState>().pricing.length,
              };
              try {
                if (isNew) {
                  await context.read<AdminState>().addPricing(body);
                } else {
                  await context.read<AdminState>().savePricing(plan!['id'] as String, body);
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
