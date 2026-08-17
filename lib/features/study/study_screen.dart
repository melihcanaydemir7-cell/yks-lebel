import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/xp_progress_bar.dart';
import '../../data/models/content.dart';
import '../../data/models/progress.dart';
import '../../routing/app_router.dart';
import '../../state/content_providers.dart';
import '../../state/progress_controller.dart';

/// Number of solved questions treated as "full" subject progress. Purely a
/// motivational scale for the MVP — not an academic measure.
const int kSubjectMasteryTarget = 200;

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subjects = ref.watch(subjectsProvider);
    final stats = ref.watch(
      progressControllerProvider.select((p) => p.subjectStats),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyTitle)),
      body: subjects.when(
        loading: () => const AppLoadingView(),
        error: (_, _) =>
            AppErrorView(onRetry: () => ref.invalidate(subjectsProvider)),
        data: (all) {
          if (all.isEmpty) return AppEmptyView(message: l10n.studyEmpty);
          final tyt = all.where((s) => s.examType == 'TYT').toList();
          final ayt = all.where((s) => s.examType == 'AYT').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                l10n.studySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (tyt.isNotEmpty) ...[
                SectionHeader(title: l10n.studySectionTyt),
                ...tyt.map(
                  (subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SubjectCard(
                      subject: subject,
                      stats: stats[subject.code] ?? const SubjectStats(),
                    ),
                  ),
                ),
              ],
              if (ayt.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionHeader(title: l10n.studySectionAyt),
                ...ayt.map(
                  (subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SubjectCard(
                      subject: subject,
                      stats: stats[subject.code] ?? const SubjectStats(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SubjectCard extends StatelessWidget {
  const SubjectCard({required this.subject, required this.stats, super.key});

  final Subject subject;
  final SubjectStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = Color(subject.color);
    final ratio = (stats.solved / kSubjectMasteryTarget).clamp(0.0, 1.0);
    final enabled = subject.isActive;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AppCard(
        onTap: enabled
            ? () => context.push(AppRoutes.subjectTopics(subject.code))
            : null,
        semanticLabel: subject.name,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                L10nMaps.subjectIcon(subject.icon),
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        enabled
                            ? l10n.studyProgressPercent((ratio * 100).round())
                            : l10n.commonSoon,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  XpProgressBar(value: ratio, height: 8, color: color),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.studySolvedCount(stats.solved)} · '
                    '${L10nMaps.mastery(l10n, stats.solved)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
