import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.days, this.semanticLabel, super.key});

  final int days;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final active = days > 0;
    final color = active
        ? AppPalette.streak
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: active ? 1 : 0.45,
              child: const Text('🔥', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 6),
            Text(
              '$days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge({required this.label, this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.secondary],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: (compact
                ? Theme.of(context).textTheme.labelMedium
                : Theme.of(context).textTheme.titleMedium)
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    required this.avatarId,
    required this.name,
    this.size = 48,
    this.showPremiumBadge = false,
    super.key,
  });

  final int avatarId;
  final String name;
  final double size;
  final bool showPremiumBadge;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.avatarColor(avatarId);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.25)!],
              ),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42,
              ),
            ),
          ),
          if (showPremiumBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppPalette.gold,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.24,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
