import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/xp_progress_bar.dart';
import '../../domain/achievement.dart';
import '../../state/progress_controller.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(achievementStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAchievementsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: Achievements.all.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final achievement = Achievements.all[index];
          final progress = Achievements.progressFor(achievement, stats);
          final unlocked = progress >= achievement.threshold;

          return AppCard(
            borderColor: unlocked ? AppPalette.success : null,
            child: Row(
              children: [
                Opacity(
                  opacity: unlocked ? 1 : 0.4,
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (unlocked ? AppPalette.success : Colors.grey)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nMaps.achievementName(l10n, achievement.id),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L10nMaps.achievementBody(l10n, achievement.id),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      XpProgressBar(
                        value: (progress / achievement.threshold).clamp(
                          0.0,
                          1.0,
                        ),
                        height: 7,
                        color: unlocked ? AppPalette.success : AppPalette.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  unlocked
                      ? '✓'
                      : '$progress/${achievement.threshold}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: unlocked
                        ? AppPalette.success
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
