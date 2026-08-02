import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/channel_categories.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final q = state.channelQuery.toLowerCase();
    final all = state.channels;
    final filtered = all.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final cat = (c['category'] as String? ?? '').toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || cat.contains(q);
      final matchesCategory =
          _categoryFilter == 'all' || (c['category'] as String?) == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();

    final canReorder = q.isEmpty && _categoryFilter == 'all';

    return AdminPage(
      toolbar: [
        Expanded(child: SearchField(hint: 'Tafuta kituo…', onChanged: state.setChannelQuery)),
        const SizedBox(width: 12),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => openChannelEditor(context, isNew: true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryChips(
            selected: _categoryFilter,
            onSelect: (v) => setState(() => _categoryFilter = v),
          ),
          const SizedBox(height: 12),
          if (!canReorder)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Futa utafutaji na uchague "Zote" ili kupanga vituo kwa kubeba',
                style: AdminTheme.body(11, color: AdminColors.textHint),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Hakuna vituo',
                      style: AdminTheme.body(13, color: AdminColors.textHint),
                    ),
                  )
                : canReorder
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: filtered.length,
                        onReorderItem: (oldIndex, newIndex) => runWithErrorSnackBar(
                          context,
                          () => context.read<AdminState>().reorderChannel(oldIndex, newIndex),
                        ),
                        itemBuilder: (_, i) => _ChannelTile(
                          key: ValueKey(filtered[i]['id']),
                          channel: filtered[i],
                          index: i,
                          draggable: true,
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ChannelTile(
                          key: ValueKey(filtered[i]['id']),
                          channel: filtered[i],
                          index: i,
                          draggable: false,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

Future<void> openChannelEditor(
  BuildContext context, {
  required bool isNew,
  Map<String, dynamic>? channel,
}) async {
  final name = TextEditingController(text: channel?['name'] as String? ?? '');
  final image = TextEditingController(text: channel?['image'] as String? ?? '');
  final description = TextEditingController(text: channel?['description'] as String? ?? '');
  final stream = TextEditingController(text: channel?['streamUrl'] as String? ?? '');
  final clearKey = TextEditingController(text: channel?['drmClearKey'] as String? ?? '');
  var category = channel?['category'] as String? ?? 'Bure';
  if (!kChannelCategories.contains(category)) category = kChannelCategories.first;
  var player = channel?['playerEngine'] as String? ?? 'exoplayer';
  var drm = channel?['drmType'] as String? ?? 'none';
  var premium = channel?['isPremium'] == true;
  var live = channel?['isLive'] == true;
  var enabled = channel?['enabled'] != false;
  var saving = false;
  String? formError;

  await showAdminSheet(
    context: context,
    title: isNew ? 'Kituo kipya' : 'Hariri kituo',
    child: StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isNew)
            Text(
              'ID: ${channel!['id']}',
              style: AdminTheme.body(11, color: AdminColors.textHint, weight: FontWeight.w700),
            ),
          if (!isNew) const SizedBox(height: 10),
          adminFieldLabel('Jina'),
          adminTextField(controller: name, hint: 'Soka TV'),
          const SizedBox(height: 14),
          adminFieldLabel('Kategoria'),
          DropdownButtonFormField<String>(
            initialValue: category,
            dropdownColor: AdminColors.surfaceLight,
            style: AdminTheme.body(14, color: AdminColors.textPrimary),
            items: kChannelCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setLocal(() => category = v ?? category),
          ),
          const SizedBox(height: 14),
          adminFieldLabel('URL ya Picha'),
          adminTextField(controller: image, hint: 'https://…'),
          const SizedBox(height: 14),
          adminFieldLabel('Maelezo'),
          adminTextField(controller: description, hint: 'Maelezo mafupi', maxLines: 2),
          const SizedBox(height: 14),
          adminFieldLabel('URL ya Kituo'),
          adminTextField(controller: stream, hint: 'https://stream…m3u8'),
          const SizedBox(height: 14),
          adminFieldLabel('Player'),
          DropdownButtonFormField<String>(
            initialValue: player,
            dropdownColor: AdminColors.surfaceLight,
            style: AdminTheme.body(14, color: AdminColors.textPrimary),
            items: const [
              DropdownMenuItem(value: 'exoplayer', child: Text('ExoPlayer')),
              DropdownMenuItem(value: 'shaka', child: Text('Shaka')),
              DropdownMenuItem(value: 'webview', child: Text('WebView')),
            ],
            onChanged: (v) => setLocal(() => player = v ?? player),
          ),
          const SizedBox(height: 14),
          adminFieldLabel('DRM'),
          DropdownButtonFormField<String>(
            value: drm,
            dropdownColor: AdminColors.surfaceLight,
            style: AdminTheme.body(14, color: AdminColors.textPrimary),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Hakuna')),
              DropdownMenuItem(value: 'clearkey', child: Text('ClearKey')),
              DropdownMenuItem(value: 'widevine', child: Text('Widevine')),
            ],
            onChanged: (v) => setLocal(() => drm = v ?? drm),
          ),
          if (drm == 'widevine') ...[
            const SizedBox(height: 8),
            Text(
              'Widevine hupata leseni moja kwa moja kutoka URL ya kituo — hakuna haja ya kuweka data zaidi.',
              style: AdminTheme.body(11, color: AdminColors.textHint),
            ),
          ],
          if (drm == 'clearkey') ...[
            const SizedBox(height: 14),
            adminFieldLabel('Funguo ya ClearKey (keyId:key)'),
            adminTextField(
              controller: clearKey,
              hint: '9eb4050deb18485bbba2e9358c988e39:6dc75f6d…',
            ),
          ],
          adminSwitchTile(
            title: 'Malipo',
            subtitle: premium
                ? 'Premium — inahitaji malipo'
                : 'Bure — inaonekana kwenye Chaneli za Bure',
            value: premium,
            onChanged: (v) => setLocal(() => premium = v),
          ),
          adminSwitchTile(
            title: 'LIVE',
            value: live,
            onChanged: (v) => setLocal(() => live = v),
          ),
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
                'image': image.text.trim(),
                'category': category,
                'description': description.text.trim(),
                'streamUrl': stream.text.trim(),
                'playerEngine': player,
                'drmType': drm,
                'drmLicenseUrl': '',
                'drmClearKey': drm == 'clearkey' ? clearKey.text.trim() : '',
                'isPremium': premium,
                'isLive': live,
                'enabled': enabled,
              };
              try {
                if (isNew) {
                  await context.read<AdminState>().addChannel(body);
                } else {
                  await context.read<AdminState>().saveChannel(channel!['id'] as String, body);
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = ['all', ...kChannelCategories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = options[i];
          final label = v == 'all' ? 'Zote' : v;
          final active = v == selected;
          return ChoiceChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => onSelect(v),
            showCheckmark: false,
            labelStyle: AdminTheme.body(
              12,
              color: active ? Colors.white : AdminColors.textSecondary,
              weight: FontWeight.w700,
            ),
            selectedColor: AdminColors.green,
            backgroundColor: AdminColors.surfaceLight.withValues(alpha: 0.45),
            side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    super.key,
    required this.channel,
    required this.index,
    required this.draggable,
  });

  final Map<String, dynamic> channel;
  final int index;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final name = channel['name'] as String? ?? '';
    final image = channel['image'] as String? ?? '';
    final premium = channel['isPremium'] == true;
    final live = channel['isLive'] == true;
    final enabled = channel['enabled'] != false;
    final drm = channel['drmType'] as String? ?? 'none';
    final stream = channel['streamUrl'] as String? ?? '';

    return AdminListTile(
      dragHandle: draggable
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator_rounded, color: AdminColors.textHint),
            )
          : null,
      leading: _ChannelThumb(name: name, image: image),
      title: name,
      subtitle: channel['category'] as String? ?? '',
      badges: [
        if (live) const StatusBadge('LIVE', color: AdminColors.danger),
        StatusBadge(
          premium ? 'MALIPO' : 'BURE',
          color: premium ? AdminColors.warning : AdminColors.info,
        ),
        StatusBadge('DRM $drm', color: AdminColors.textSecondary),
        StatusBadge(
          enabled ? 'Hai' : 'Zimwa',
          color: enabled ? AdminColors.green : AdminColors.textHint,
        ),
      ],
      footer: stream.isEmpty
          ? null
          : Row(
              children: [
                const Icon(Icons.link_rounded, size: 13, color: AdminColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    stream,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTheme.body(11, color: AdminColors.textHint),
                  ),
                ),
              ],
            ),
      actions: [
        IconButton(
          tooltip: 'Nakili URL',
          onPressed: stream.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: stream));
                  showSuccessSnackBar(context, 'URL imenakiliwa');
                },
          icon: const Icon(Icons.copy_rounded, color: AdminColors.textSecondary, size: 18),
        ),
        IconButton(
          tooltip: 'Hariri',
          onPressed: () => openChannelEditor(context, isNew: false, channel: channel),
          icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
        ),
        DeleteIconButton(
          onDelete: () => deleteWithConfirm(
            context,
            dialogTitle: 'Futa kituo',
            itemName: name,
            onDelete: () => context.read<AdminState>().removeChannel(channel['id'] as String),
          ),
        ),
      ],
    );
  }
}

class _ChannelThumb extends StatelessWidget {
  const _ChannelThumb({required this.name, required this.image});

  final String name;
  final String image;

  @override
  Widget build(BuildContext context) {
    final fallback = _initials();
    if (image.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        image,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }

  Widget _initials() {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AdminColors.navyMid, Color(0xFF2C6DB5)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(letter, style: AdminTheme.body(16, color: Colors.white, weight: FontWeight.w800)),
    );
  }
}
