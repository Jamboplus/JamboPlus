import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_theme.dart';

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  const AdminHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenu,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final Widget? trailing;

  static const _minTopInset = 8.0;

  @override
  Size get preferredSize {
    final base = subtitle == null ? 64.0 : 78.0;
    return Size.fromHeight(base + _minTopInset);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final top = topInset > 0 ? topInset : _minTopInset;

    return Material(
      color: AdminColors.bg,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, top + 4, 16, 12),
        decoration: BoxDecoration(
          color: AdminColors.bg,
          border: Border(
            bottom: BorderSide(color: AdminColors.border.withValues(alpha: 0.28)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onMenu != null)
              IconButton(
                onPressed: onMenu,
                tooltip: 'Menyu',
                icon: const Icon(Icons.menu_rounded, color: AdminColors.textPrimary),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTheme.heading(22),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTheme.body(12, color: AdminColors.textHint),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Keeps admin status bar icons readable on the dark shell.
void applyAdminSystemChrome() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AdminColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}
