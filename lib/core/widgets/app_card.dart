import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded surface used for every block in the app. Tapping is optional so the
/// same visual language works for both static and interactive cards.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTheme.radius);

    final content = Padding(padding: padding, child: child);

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: color ?? theme.cardTheme.color,
        clipBehavior: Clip.antiAlias,
        // `shape` and `borderRadius` are mutually exclusive on Material, and
        // the shape is what lets a card carry an accent border.
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: 1.5),
        ),
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
  }
}
