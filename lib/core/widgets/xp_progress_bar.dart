import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Chunky, animated XP bar. Deliberately thicker than a stock LinearProgress
/// indicator so it reads as a game element.
class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    required this.value,
    this.height = 14,
    this.color,
    this.backgroundColor,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = color ?? AppPalette.xp;
    final track =
        backgroundColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.10);

    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: track),
            LayoutBuilder(
              builder: (context, constraints) => AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(
                    colors: [fill, Color.lerp(fill, Colors.white, 0.35)!],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
