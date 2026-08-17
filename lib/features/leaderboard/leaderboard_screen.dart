import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/xp_progress_bar.dart';
import '../../data/models/leaderboard.dart';
import '../../domain/league.dart';
import '../../state/app_flow_controller.dart';
import '../../services/analytics_service.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';

final leaderboardProvider = FutureProvider.autoDispose<LeaderboardPage>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(leaderboardRepositoryProvider);
  if (!repository.isAvailable || !user.isSignedIn) return LeaderboardPage.empty;
  return repository.weeklyTop(currentUserId: user.id);
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.leaderboardViewed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final progress = ref.watch(progressControllerProvider);
    final league = ref.watch(leagueProvider);
    final canCompete =
        user.isSignedIn && ref.watch(leaderboardRepositoryProvider).isAvailable;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leagueTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          LeagueCard(league: league, weeklyXp: progress.currentWeekXp),
          const SizedBox(height: 20),
          SectionHeader(title: l10n.leagueWeeklySubtitle),
          if (!canCompete)
            const _SignInPrompt()
          else
            const _LeaderboardList(),
          const SizedBox(height: 16),
          Text(
            l10n.leagueResetInfo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class LeagueCard extends StatelessWidget {
  const LeagueCard({required this.league, required this.weeklyXp, super.key});

  final League league;
  final int weeklyXp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = L10nMaps.leagueColor(league);
    final next = league.next;
    final remaining = league.xpToNext(weeklyXp);

    final ratio = next == null
        ? 1.0
        : ((weeklyXp - league.weeklyXpThreshold) /
                  (next.weeklyXpThreshold - league.weeklyXpThreshold))
              .clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nMaps.league(l10n, league),
                      style: theme.textTheme.titleLarge?.copyWith(color: color),
                    ),
                    Text(
                      l10n.leagueYourWeeklyXp(weeklyXp),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          XpProgressBar(value: ratio, color: color),
          const SizedBox(height: 10),
          Text(
            next == null || remaining == null
                ? l10n.leagueTopReached
                : l10n.leagueToNext(L10nMaps.league(l10n, next), remaining),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends ConsumerWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            l10n.leagueSignInTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.leagueSignInBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () =>
                ref.read(appFlowControllerProvider.notifier).resetAuthGate(),
            child: Text(l10n.leagueSignInCta),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  const _LeaderboardList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(leaderboardProvider);

    return page.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppLoadingView(),
      ),
      error: (_, _) => AppErrorView(
        message: l10n.leagueOffline,
        onRetry: () => ref.invalidate(leaderboardProvider),
      ),
      data: (data) {
        if (data.entries.isEmpty) {
          return AppEmptyView(message: l10n.leagueEmpty, emoji: '🥇');
        }
        return Column(
          children: [
            ...data.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LeaderboardRow(entry: entry),
              ),
            ),
            if (data.currentUserEntry != null) ...[
              const Divider(height: 24),
              LeaderboardRow(entry: data.currentUserEntry!),
            ],
          ],
        );
      },
    );
  }
}

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({required this.entry, super.key});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final medal = switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: entry.isCurrentUser ? theme.colorScheme.primary : null,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text(
                    '${entry.rank}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          AvatarCircle(
            avatarId: entry.avatarId,
            name: entry.username,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.isCurrentUser ? l10n.leagueYou : entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            '${entry.weeklyXp} XP',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
