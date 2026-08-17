import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n_extension.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/content.dart';
import '../../data/models/quiz.dart';
import '../../domain/combo.dart';
import '../../domain/xp.dart';
import '../../routing/app_router.dart';
import '../../services/analytics_service.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({required this.args, super.key});

  final QuizArgs args;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late Future<List<Question>> _questionsFuture;
  List<Question> _questions = const [];

  int _index = 0;
  String? _selected;
  int _combo = 0;
  int _bestCombo = 0;
  int _correct = 0;
  int _baseXp = 0;
  int _lastAnswerXp = 0;
  final List<QuestionAttempt> _attempts = [];

  late DateTime _sessionStartedAt;
  late DateTime _questionStartedAt;
  bool _finishing = false;

  int get _count =>
      widget.args.questionCount ?? AppConfig.questionsPerSession;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _questionStartedAt = _sessionStartedAt;
    _questionsFuture = _loadQuestions();

    ref.read(analyticsProvider).logEvent(
      AnalyticsEvents.quizStarted,
      <String, Object?>{
        'subject': widget.args.subjectCode,
        'topic': widget.args.topicCode,
        'question_count': _count,
        'source': widget.args.source.name,
      },
    );
  }

  Future<List<Question>> _loadQuestions() async {
    final repository = ref.read(contentRepositoryProvider);

    // "Günün Sorusu" is a single pinned question shared by every user that
    // day, not a random draw from the same topic.
    if (widget.args.source == QuizSource.dailyQuestion) {
      final question = await repository.questionOfTheDay();
      return question == null ? const <Question>[] : <Question>[question];
    }

    return repository.sessionQuestions(
      count: _count,
      subjectCode: widget.args.subjectCode,
      topicCode: widget.args.topicCode,
    );
  }

  void _answer(Question question, String option) {
    if (_selected != null) return;

    final isCorrect = question.isCorrect(option);
    final combo = ComboService.next(current: _combo, isCorrect: isCorrect);
    final xp = XpService.xpForAnswer(isCorrect: isCorrect, combo: combo);
    final elapsed = DateTime.now().difference(_questionStartedAt);

    setState(() {
      _selected = option;
      _combo = combo;
      _bestCombo = combo > _bestCombo ? combo : _bestCombo;
      _lastAnswerXp = xp;
      if (isCorrect) _correct++;
      _baseXp += xp;
      _attempts.add(
        QuestionAttempt(
          questionId: question.id,
          subjectCode: question.subjectCode,
          topicCode: question.topicCode,
          selectedOption: option,
          isCorrect: isCorrect,
          responseTimeMs: elapsed.inMilliseconds,
          xpAwarded: xp,
          answeredAt: DateTime.now(),
        ),
      );
    });

    final feedback = ref.read(feedbackServiceProvider);
    isCorrect ? feedback.correct() : feedback.wrong();

    ref.read(analyticsProvider).logEvent(
      AnalyticsEvents.questionAnswered,
      <String, Object?>{
        'subject': question.subjectCode,
        'topic': question.topicCode,
        'is_correct': isCorrect,
        'combo': combo,
        'xp_earned': xp,
        'difficulty': question.difficulty.name,
      },
    );
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _lastAnswerXp = 0;
        _questionStartedAt = DateTime.now();
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;

    final result = QuizResult(
      subjectCode: widget.args.subjectCode,
      topicCode: widget.args.topicCode,
      source: widget.args.source,
      total: _attempts.length,
      correct: _correct,
      baseXp: _baseXp,
      bestCombo: _bestCombo,
      duration: DateTime.now().difference(_sessionStartedAt),
      attempts: List.unmodifiable(_attempts),
    );

    final rewards = await ref
        .read(progressControllerProvider.notifier)
        .applySession(result);

    if (!mounted) return;
    context.pushReplacement(
      AppRoutes.quizResult,
      extra: QuizResultArgs(
        result: result,
        rewards: rewards,
        origin: widget.args,
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.quizExitTitle),
        content: Text(l10n.quizExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.quizExitStay),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.quizExitConfirm),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<List<Question>>(
            future: _questionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppLoadingView();
              }
              if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                return AppErrorView(
                  message: l10n.quizLoadFailed,
                  onRetry: () => context.pop(),
                );
              }
              _questions = snapshot.data!;
              return _buildQuiz(context, _questions[_index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context, Question question) {
    final answered = _selected != null;
    final isCorrect = answered && question.isCorrect(_selected!);

    return Column(
      children: [
        _QuizHeader(
          current: _index + 1,
          total: _questions.length,
          combo: _combo,
          onClose: () async {
            final leave = await _confirmExit();
            if (leave && context.mounted) context.pop();
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        child: Image.network(
                          question.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      question.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...question.optionKeys.map(
                (key) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnswerOption(
                    optionKey: key,
                    text: question.optionText(key),
                    state: _stateFor(question, key),
                    onTap: answered ? null : () => _answer(question, key),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (answered)
          _AnswerFeedback(
            isCorrect: isCorrect,
            xp: _lastAnswerXp,
            correctOption: question.correctOption,
            explanation: question.explanation,
            isLast: _index == _questions.length - 1,
            variant: _index,
            onContinue: _next,
          ),
      ],
    );
  }

  AnswerState _stateFor(Question question, String key) {
    if (_selected == null) return AnswerState.idle;
    if (question.isCorrect(key)) return AnswerState.correct;
    if (key == _selected) return AnswerState.wrong;
    return AnswerState.dimmed;
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.current,
    required this.total,
    required this.combo,
    required this.onClose,
  });

  final int current;
  final int total;
  final int combo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tier = ComboService.tierFor(combo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.commonClose,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: current / total,
                minHeight: 10,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.quizProgress(current, total),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (tier != ComboTier.none) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.streak.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tier == ComboTier.onFire
                    ? l10n.quizOnFire
                    : l10n.quizCombo(combo),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppPalette.streak,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum AnswerState { idle, correct, wrong, dimmed }

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    required this.optionKey,
    required this.text,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String optionKey;
  final String text;
  final AnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color border, Color background, Color foreground) = switch (state) {
      AnswerState.correct => (
        AppPalette.success,
        AppPalette.success.withValues(alpha: 0.14),
        AppPalette.successDark,
      ),
      AnswerState.wrong => (
        AppPalette.danger,
        AppPalette.danger.withValues(alpha: 0.12),
        AppPalette.danger,
      ),
      AnswerState.dimmed => (
        Colors.transparent,
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        theme.colorScheme.onSurfaceVariant,
      ),
      AnswerState.idle => (
        theme.colorScheme.outlineVariant,
        theme.cardTheme.color ?? theme.colorScheme.surface,
        theme.colorScheme.onSurface,
      ),
    };

    return Semantics(
      button: true,
      selected: state == AnswerState.correct || state == AnswerState.wrong,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    optionKey,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      height: 1.35,
                    ),
                  ),
                ),
                if (state == AnswerState.correct)
                  const Icon(Icons.check_circle_rounded, color: AppPalette.success),
                if (state == AnswerState.wrong)
                  const Icon(Icons.cancel_rounded, color: AppPalette.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({
    required this.isCorrect,
    required this.xp,
    required this.correctOption,
    required this.explanation,
    required this.isLast,
    required this.variant,
    required this.onContinue,
  });

  final bool isCorrect;
  final int xp;
  final String correctOption;
  final String? explanation;
  final bool isLast;

  /// Rotates the headline copy so ten questions in a row do not read like the
  /// same canned response.
  final int variant;
  final VoidCallback onContinue;

  String _headline(L10n l10n) {
    if (isCorrect) {
      return switch (variant % 3) {
        0 => l10n.quizCorrect,
        1 => l10n.quizCorrectAlt,
        _ => l10n.quizCorrectAlt2,
      };
    }
    return variant.isEven ? l10n.quizWrong : l10n.quizWrongAlt;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = isCorrect ? AppPalette.success : AppPalette.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _headline(l10n),
                    style: theme.textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
                if (isCorrect)
                  Text(
                    l10n.xpReward(xp),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppPalette.xp,
                    ),
                  ),
              ],
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 4),
              Text(
                l10n.quizCorrectAnswer(correctOption),
                style: theme.textTheme.titleSmall,
              ),
            ],
            if ((explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.quizExplanation,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                explanation!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: onContinue,
              child: Text(isLast ? l10n.quizFinish : l10n.commonContinue),
            ),
          ],
        ),
      ),
    );
  }
}
