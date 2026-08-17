import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/xp_progress_bar.dart';
import '../../domain/achievement.dart';
import '../../domain/xp.dart';
import '../../routing/app_router.dart';
import '../../state/content_providers.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../study/study_screen.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final progress = ref.watch(progressControllerProvider);
    final streak = ref.watch(visibleStreakProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final level = XpService.levelForTotalXp(progress.totalXp);
    final unlocked = progress.unlockedAchievements.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileSettings,
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarCircle(
                      avatarId: progress.avatarId,
                      name: progress.username,
                      size: 64,
                      showPremiumBadge: isPremium,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.username.isEmpty
                                ? l10n.profileGuest
                                : progress.username,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              LevelBadge(
                                label: l10n.profileLevel(level),
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.profileTotalXp(progress.totalXp),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.profileEdit,
                      onPressed: () => showEditProfileSheet(context),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                XpProgressBar(value: XpService.levelProgress(progress.totalXp)),
              ],
            ),
          ),

          const SizedBox(height: 12),
          AppCard(
            onTap: isPremium ? null : () => context.push(AppRoutes.premium),
            color: isPremium
                ? AppPalette.gold.withValues(alpha: 0.14)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isPremium ? Icons.star_rounded : Icons.workspace_premium_outlined,
                  color: AppPalette.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPremium
                        ? l10n.profilePremiumActive
                        : l10n.profilePremiumCta,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (!isPremium) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SectionHeader(title: l10n.profileStatsTitle),
          _StatsGrid(
            items: [
              (l10n.statTotalQuestions, '${progress.totalQuestions}'),
              (l10n.statTotalCorrect, '${progress.totalCorrect}'),
              (l10n.statAccuracy, '%${(progress.accuracy * 100).round()}'),
              (l10n.statCurrentStreak, '$streak ${l10n.profileDaysUnit}'),
              (
                l10n.statLongestStreak,
                '${progress.longestStreak} ${l10n.profileDaysUnit}',
              ),
              (
                l10n.statStudyDays,
                '${progress.studyDays.length} ${l10n.profileDaysUnit}',
              ),
            ],
          ),

          const SizedBox(height: 24),
          SectionHeader(
            title: l10n.profileAchievementsTitle,
            trailing: TextButton(
              onPressed: () => context.push(AppRoutes.achievements),
              child: Text(
                l10n.profileAchievementsCount(unlocked, Achievements.all.length),
              ),
            ),
          ),
          const _AchievementStrip(),

          const SizedBox(height: 24),
          SectionHeader(title: l10n.profileSubjectsTitle),
          const _SubjectProgressList(),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final width = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _AchievementStrip extends ConsumerWidget {
  const _AchievementStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(achievementStatsProvider);

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Achievements.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final achievement = Achievements.all[index];
          final unlocked = Achievements.isUnlocked(achievement, stats);
          return Opacity(
            opacity: unlocked ? 1 : 0.45,
            child: SizedBox(
              width: 104,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L10nMaps.achievementName(l10n, achievement.id),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubjectProgressList extends ConsumerWidget {
  const _SubjectProgressList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subjects = ref.watch(subjectsProvider);
    final stats = ref.watch(
      progressControllerProvider.select((p) => p.subjectStats),
    );

    return subjects.when(
      loading: () => const AppLoadingView(),
      error: (_, _) =>
          AppErrorView(onRetry: () => ref.invalidate(subjectsProvider)),
      data: (all) {
        final studied = all
            .where((s) => (stats[s.code]?.solved ?? 0) > 0)
            .toList();
        if (studied.isEmpty) {
          return AppEmptyView(message: l10n.profileSubjectsEmpty, emoji: '📚');
        }
        return Column(
          children: studied
              .map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SubjectRow(
                    name: subject.name,
                    icon: L10nMaps.subjectIcon(subject.icon),
                    color: Color(subject.color),
                    solved: stats[subject.code]!.solved,
                    accuracy: stats[subject.code]!.accuracy,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.name,
    required this.icon,
    required this.color,
    required this.solved,
    required this.accuracy,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int solved;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                XpProgressBar(
                  value: (solved / kSubjectMasteryTarget).clamp(0.0, 1.0),
                  height: 7,
                  color: color,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '%${(accuracy * 100).round()}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                l10n.studySolvedCount(solved),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
