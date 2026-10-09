import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AdminTheme.body(11, color: color, weight: FontWeight.w800),
      ),
    );
  }
}

class AdminPrimaryButton extends StatelessWidget {
  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon ?? Icons.add_rounded, size: 18),
      label: Text(
        label,
        style: AdminTheme.body(13, color: Colors.white, weight: FontWeight.w800),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AdminTheme.body(14, color: AdminColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AdminColors.textHint,
          size: 20,
        ),
      ),
    );
  }
}

/// Compact search icon that expands into a full typing field.
class ExpandableSearchBar extends StatefulWidget {
  const ExpandableSearchBar({
    super.key,
    required this.hint,
    required this.query,
    required this.onChanged,
    this.collapsedActions = const [],
    this.persistentActions = const [],
  });

  final String hint;
  final String query;
  final ValueChanged<String> onChanged;
  final List<Widget> collapsedActions;
  final List<Widget> persistentActions;

  @override
  State<ExpandableSearchBar> createState() => _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends State<ExpandableSearchBar> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
    _focus = FocusNode();
    _open = widget.query.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ExpandableSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
    if (widget.query.trim().isNotEmpty && !_open) {
      _open = true;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focus.hasFocus) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    _ctrl.clear();
    widget.onChanged('');
    _focus.unfocus();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_open)
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.text,
              onChanged: widget.onChanged,
              style: AdminTheme.body(14, color: AdminColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AdminColors.green,
                  size: 22,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Funga',
                  onPressed: _closeSearch,
                  icon: const Icon(Icons.close_rounded, color: AdminColors.textSecondary),
                ),
              ),
            ),
          )
        else ...[
          _SearchLensButton(
            active: widget.query.trim().isNotEmpty,
            onTap: _openSearch,
          ),
          const Spacer(),
          ...widget.collapsedActions,
        ],
        ...widget.persistentActions,
      ],
    );
  }
}

class _SearchLensButton extends StatelessWidget {
  const _SearchLensButton({required this.onTap, required this.active});

  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AdminColors.green.withValues(alpha: 0.55)
                  : AdminColors.border.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.search_rounded,
            color: active ? AdminColors.green : AdminColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class AdminIconAction extends StatelessWidget {
  const AdminIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (filled ? Colors.white : AdminColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? AdminColors.green : AdminColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: filled
                    ? null
                    : Border.all(color: AdminColors.border.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
