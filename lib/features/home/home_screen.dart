import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/xp_progress_bar.dart';
import '../../data/models/quiz.dart';
import '../../domain/daily_quest.dart';
import '../../domain/streak.dart';
import '../../domain/xp.dart';
import '../../core/utils/tr_date.dart';
import '../../routing/app_router.dart';
import '../../state/app_flow_controller.dart';
import '../../state/content_providers.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A user who leaves the app open overnight should still see today's quests.
    if (state == AppLifecycleState.resumed) {
      ref.read(progressControllerProvider.notifier).refreshDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = ref.watch(progressControllerProvider);
    final streak = ref.watch(visibleStreakProvider);
    final quests = ref.watch(dailyQuestsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(contentRepositoryProvider).invalidate();
            ref.invalidate(dailyQuestionProvider);
            ref.invalidate(dailyFactProvider);
            await ref.read(progressControllerProvider.notifier).refreshDay();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Greeting(username: progress.username, streak: streak),
              const SizedBox(height: 20),
              _LevelCard(totalXp: progress.totalXp),

              if (StreakService.isAtRisk(
                today: TrDate.todayKey(),
                lastCompletedDate: progress.lastCompletedDate,
                completedToday:
                    progress.today.solved >= AppConfig.questionsForStreakDay,
              )) ...[
                const SizedBox(height: 12),
                _StreakWarning(
                  remaining:
                      AppConfig.questionsForStreakDay - progress.today.solved,
                ),
              ],

              if (user.isGuest && ref.watch(authAvailableProvider)) ...[
                const SizedBox(height: 16),
                const _GuestBanner(),
              ],

              const SizedBox(height: 28),
              SectionHeader(title: l10n.homeQuestsTitle),
              ...quests.map(
                (quest) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuestTile(quest: quest),
                ),
              ),

              const SizedBox(height: 20),
              SectionHeader(title: l10n.homeDailyQuestionTitle),
              const _DailyQuestionCard(),

              const SizedBox(height: 24),
              SectionHeader(title: l10n.homeFactTitle),
              const _DailyFactCard(),

              const SizedBox(height: 24),
              SectionHeader(title: l10n.homeTodayTitle),
              _TodayStats(
                solved: progress.today.solved,
                xp: progress.today.xpEarned,
                accuracy: progress.today.accuracy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.username, required this.streak});

  final String username;
  final int streak;

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = context.l10n;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 18) return l10n.greetingDay;
    return l10n.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = username.trim().isEmpty ? l10n.homeDefaultName : username;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(context),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
        StreakBadge(days: streak, semanticLabel: l10n.homeStreakDays(streak)),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.totalXp});

  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final level = XpService.levelForTotalXp(totalXp);
    final into = XpService.xpIntoLevel(totalXp);
    final span = XpService.xpForCurrentLevel(totalXp);
    final remaining = XpService.xpToNextLevel(totalXp);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LevelBadge(label: l10n.homeLevelBadge(level)),
              const Spacer(),
              Text(
                span == 0
                    ? '$totalXp XP'
                    : l10n.homeXpOfTotal(into, span),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          XpProgressBar(value: XpService.levelProgress(totalXp)),
          const SizedBox(height: 10),
          Text(
            span == 0 ? l10n.homeMaxLevel : l10n.homeXpToNext(remaining),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakWarning extends StatelessWidget {
  const _StreakWarning({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppPalette.streak.withValues(alpha: 0.12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        const Text('🔥', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.homeStreakAtRisk(remaining < 1 ? 1 : remaining),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _GuestBanner extends ConsumerWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AppCard(
      borderColor: AppPalette.primary.withValues(alpha: 0.35),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGuestBannerTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeGuestBannerBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () =>
                ref.read(appFlowControllerProvider.notifier).resetAuthGate(),
            child: Text(l10n.homeGuestBannerCta),
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});

  final QuestProgress quest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final done = quest.isCompleted;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (done ? AppPalette.success : AppPalette.primary)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.flag_rounded,
              color: done ? AppPalette.success : AppPalette.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nMaps.quest(l10n, quest.definition.id),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                XpProgressBar(
                  value: quest.ratio,
                  height: 8,
                  color: done ? AppPalette.success : AppPalette.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  done
                      ? l10n.questCompleted
                      : l10n.questProgress(quest.progress, quest.target),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.xpReward(quest.definition.xpReward),
            style: theme.textTheme.titleSmall?.copyWith(
              color: done ? AppPalette.success : AppPalette.xp,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestionCard extends ConsumerWidget {
  const _DailyQuestionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final question = ref.watch(dailyQuestionProvider);
    final answered = ref.watch(
      progressControllerProvider.select((p) => p.today.dailyQuestionAnswered),
    );

    return question.when(
      loading: () => const AppCard(
        child: SizedBox(height: 72, child: AppLoadingView()),
      ),
      error: (_, _) => AppCard(
        child: AppErrorView(
          message: l10n.commonError,
          onRetry: () => ref.invalidate(dailyQuestionProvider),
        ),
      ),
      data: (value) {
        if (value == null) {
          return AppCard(child: AppEmptyView(message: l10n.studyEmpty));
        }
        return AppCard(
          onTap: answered
              ? null
              : () => context.push(
                  AppRoutes.quiz,
                  extra: QuizArgs(
                    subjectCode: value.subjectCode,
                    topicCode: value.topicCode,
                    source: QuizSource.dailyQuestion,
                    questionCount: 1,
                  ),
                ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('❓', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      answered
                          ? l10n.homeDailyQuestionDone
                          : l10n.homeDailyQuestionCta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: answered
                            ? AppPalette.success
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!answered) const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      },
    );
  }
}

class _DailyFactCard extends ConsumerWidget {
  const _DailyFactCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fact = ref.watch(dailyFactProvider);
    return fact.when(
      loading: () => const AppCard(
        child: SizedBox(height: 56, child: AppLoadingView()),
      ),
      error: (_, _) => AppCard(
        child: AppErrorView(onRetry: () => ref.invalidate(dailyFactProvider)),
      ),
      data: (value) => AppCard(
        color: AppPalette.secondary.withValues(alpha: 0.10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value?.text ?? context.l10n.commonEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({
    required this.solved,
    required this.xp,
    required this.accuracy,
  });

  final int solved;
  final int xp;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: l10n.homeTodaySolved,
            value: '$solved',
            color: AppPalette.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: l10n.homeTodayXp,
            value: '$xp',
            color: AppPalette.xp,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: l10n.homeTodayAccuracy,
            value: '%${(accuracy * 100).round()}',
            color: AppPalette.success,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
