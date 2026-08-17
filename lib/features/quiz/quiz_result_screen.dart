import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/quiz.dart';
import '../../domain/progress_engine.dart';
import '../../domain/xp.dart';
import '../../routing/app_router.dart';
import '../../services/analytics_service.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';

class QuizResultArgs {
  const QuizResultArgs({
    required this.result,
    required this.rewards,
    required this.origin,
  });

  final QuizResult result;
  final SessionRewards rewards;
  final QuizArgs origin;
}

class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({required this.args, super.key});

  final QuizResultArgs args;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  int _bonusXp = 0;
  bool _bonusClaimed = false;
  bool _bonusBusy = false;

  QuizResult get _result => widget.args.result;
  SessionRewards get _rewards => widget.args.rewards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  Future<void> _afterFirstFrame() async {
    ref.read(feedbackServiceProvider).celebrate();

    if (_rewards.leveledUp && mounted) {
      await _showLevelUp();
    }
    for (final achievement in _rewards.newAchievements) {
      if (!mounted) return;
      await _showAchievement(achievement.id);
    }

    if (!mounted) return;
    final ads = ref.read(adServiceProvider);
    await ads.preloadRewarded();
    if (!mounted) return;
    if (ads.isRewardedReady && !_bonusClaimed) {
      await ref.read(analyticsProvider).logEvent(
        AnalyticsEvents.rewardedAdOffered,
        <String, Object?>{'xp_earned': _result.baseXp},
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _showLevelUp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Text('🎉', style: TextStyle(fontSize: 44)),
      title: Text(context.l10n.levelUpTitle, textAlign: TextAlign.center),
      content: Text(
        context.l10n.levelUpBody(_rewards.levelAfter),
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonContinue),
        ),
      ],
    ),
  );

  Future<void> _showAchievement(String id) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              L10nMaps.achievementIcon(id),
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.achievementUnlocked(L10nMaps.achievementName(l10n, id)),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
  }

  Future<void> _watchRewardedAd() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bonusBusy = true);

    final earned = await ref.read(adServiceProvider).showRewarded();

    if (!mounted) return;
    if (!earned) {
      setState(() => _bonusBusy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.resultBonusFailed)));
      return;
    }

    // XP is granted only after the SDK confirms the reward.
    final bonus = XpService.rewardedAdBonus(_result.baseXp + _rewards.questXp);
    final rewards = await ref
        .read(progressControllerProvider.notifier)
        .addBonusXp(bonus);

    await ref.read(analyticsProvider).logEvent(
      AnalyticsEvents.rewardedAdCompleted,
      <String, Object?>{'xp_earned': bonus},
    );

    if (!mounted) return;
    setState(() {
      _bonusXp = bonus;
      _bonusClaimed = true;
      _bonusBusy = false;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.resultBonusEarned(bonus))),
    );
    if (rewards.leveledUp && mounted) await _showLevelUp();
  }

  Future<void> _leave({required bool replay}) async {
    await ref.read(adServiceProvider).maybeShowInterstitial();
    if (!mounted) return;
    if (replay) {
      context.pushReplacement(AppRoutes.quiz, extra: widget.args.origin);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final adReady = ref.watch(adServiceProvider).isRewardedReady;
    final totalXp = _rewards.totalXp + _bonusXp;
    final accuracy = (_result.accuracy * 100).round();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(replay: false);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Center(
                child: Text(
                  accuracy >= 70 ? '🎉' : '💪',
                  style: const TextStyle(fontSize: 64),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                accuracy >= 70 ? l10n.resultTitleGreat : l10n.resultTitleGood,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.resultCorrectOf(_result.correct, _result.total),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              AppCard(
                color: AppPalette.xp.withValues(alpha: 0.14),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    l10n.xpReward(totalXp),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppPalette.xp,
                    ),
                  ),
                ),
              ),

              if (_rewards.streakIncremented) ...[
                const SizedBox(height: 12),
                _Banner(
                  text: l10n.streakBanner(_rewards.streak),
                  color: AppPalette.streak,
                ),
              ],
              for (final quest in _rewards.completedQuests) ...[
                const SizedBox(height: 8),
                _Banner(
                  text: l10n.resultQuestDone(L10nMaps.quest(l10n, quest.id)),
                  color: AppPalette.success,
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      label: l10n.resultAccuracy,
                      value: '%$accuracy',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      label: l10n.resultBestCombo,
                      value: 'x${_result.bestCombo}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      label: l10n.resultDuration,
                      value: _formatDuration(_result.duration),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              if (!isPremium && !_bonusClaimed && adReady) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.xp,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: _bonusBusy ? null : _watchRewardedAd,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(l10n.resultBonusCta),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: () => _leave(replay: true),
                child: Text(l10n.resultPlayAgain),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _leave(replay: false),
                child: Text(l10n.resultHome),
              ),

              const SizedBox(height: 16),
              Text(
                l10n.resultTodayXp(
                  ref.watch(
                    progressControllerProvider.select((p) => p.today.xpEarned),
                  ),
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    color: color.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: color),
    ),
  );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
