import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class CarouselScreen extends StatelessWidget {
  const CarouselScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final slides = state.carousel;

    return AdminPage(
      toolbar: [
        Text('${slides.length} slaidi', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => openCarouselEditor(context, isNew: true),
        ),
      ],
      child: slides.isEmpty
          ? Center(child: Text('Hakuna slaidi', style: AdminTheme.body(13, color: AdminColors.textHint)))
          : ListView.builder(
              itemCount: slides.length,
              itemBuilder: (_, i) {
                final s = slides[i];
                final enabled = s['enabled'] == true;
                return AdminListTile(
                  leading: _SlideThumb(image: s['image'] as String? ?? '', title: s['title'] as String? ?? ''),
                  title: s['title'] as String? ?? '',
                  subtitle: s['link'] as String? ?? '',
                  badges: [
                    StatusBadge('#${(s['sortOrder'] as num?)?.toInt() ?? i + 1}', color: AdminColors.textSecondary),
                    StatusBadge(enabled ? 'Hai' : 'Zimwa', color: enabled ? AdminColors.green : AdminColors.textHint),
                  ],
                  actions: [
                    IconButton(
                      tooltip: 'Hariri',
                      onPressed: () => openCarouselEditor(context, isNew: false, slide: s),
                      icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
                    ),
                    DeleteIconButton(
                      onDelete: () => deleteWithConfirm(
                        context,
                        dialogTitle: 'Futa slaidi',
                        itemName: s['title'] as String? ?? '',
                        onDelete: () => context.read<AdminState>().removeCarousel(s['id'] as String),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

Future<void> openCarouselEditor(
  BuildContext context, {
  required bool isNew,
  Map<String, dynamic>? slide,
}) async {
  final title = TextEditingController(text: slide?['title'] as String? ?? '');
  final image = TextEditingController(text: slide?['image'] as String? ?? '');
  final link = TextEditingController(text: slide?['link'] as String? ?? '');
  var enabled = slide?['enabled'] != false;
  var saving = false;
  String? formError;

  await showAdminSheet(
    context: context,
    title: isNew ? 'Slaidi mpya' : 'Hariri slaidi',
    child: StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminFieldLabel('Jina'),
          adminTextField(controller: title, hint: 'Mpira wa Moja kwa Moja'),
          const SizedBox(height: 14),
          adminFieldLabel('URL ya Picha'),
          adminTextField(controller: image, hint: 'https://…'),
          const SizedBox(height: 14),
          adminFieldLabel('Kiungo (hiari)'),
          adminTextField(controller: link),
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
              if (title.text.trim().isEmpty || image.text.trim().isEmpty) {
                setLocal(() => formError = 'Jina na picha vinahitajika');
                return;
              }
              setLocal(() {
                saving = true;
                formError = null;
              });
              final body = {
                'title': title.text.trim(),
                'image': image.text.trim(),
                'link': link.text.trim(),
                'enabled': enabled,
                if (isNew) 'sortOrder': context.read<AdminState>().carousel.length,
              };
              try {
                if (isNew) {
                  await context.read<AdminState>().addCarousel(body);
                } else {
                  await context.read<AdminState>().saveCarousel(slide!['id'] as String, body);
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

class _SlideThumb extends StatelessWidget {
  const _SlideThumb({required this.image, required this.title});

  final String image;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (image.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(image, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback()),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AdminColors.navyMid, Color(0xFF2C6DB5)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title.isNotEmpty ? title.characters.first.toUpperCase() : '?',
        style: AdminTheme.body(18, color: Colors.white, weight: FontWeight.w800),
      ),
    );
  }
}
