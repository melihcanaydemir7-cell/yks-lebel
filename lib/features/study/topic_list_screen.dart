import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/content.dart';
import '../../data/models/quiz.dart';
import '../../routing/app_router.dart';
import '../../state/content_providers.dart';

class TopicListScreen extends ConsumerStatefulWidget {
  const TopicListScreen({required this.subjectCode, super.key});

  final String subjectCode;

  @override
  ConsumerState<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends ConsumerState<TopicListScreen> {
  String? _selectedTopic;

  void _start(Subject subject) {
    context.push(
      AppRoutes.quiz,
      extra: QuizArgs(
        subjectCode: subject.code,
        topicCode: _selectedTopic,
        source: _selectedTopic == null ? QuizSource.subject : QuizSource.topic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subject = ref.watch(subjectProvider(widget.subjectCode));

    return subject.when(
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          onRetry: () => ref.invalidate(subjectProvider(widget.subjectCode)),
        ),
      ),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(),
            body: AppEmptyView(message: l10n.studyEmpty),
          );
        }
        final color = Color(value.color);

        return Scaffold(
          appBar: AppBar(title: Text(value.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _TopicOption(
                title: l10n.studyAllTopics,
                subtitle: l10n.studyAllTopicsBody,
                icon: L10nMaps.subjectIcon(value.icon),
                color: color,
                selected: _selectedTopic == null,
                onTap: () => setState(() => _selectedTopic = null),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: l10n.studyTopicsTitle),
              ...value.topics.map(
                (topic) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopicOption(
                    title: topic.name,
                    icon: Icons.radio_button_checked_rounded,
                    color: color,
                    selected: _selectedTopic == topic.code,
                    onTap: () => setState(() => _selectedTopic = topic.code),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: () => _start(value),
              child: Text(l10n.studyStart),
            ),
          ),
        );
      },
    );
  }
}

class _TopicOption extends StatelessWidget {
  const _TopicOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    borderColor: selected ? color : null,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Icon(icon, color: selected ? color : Theme.of(context).disabledColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (selected) Icon(Icons.check_circle_rounded, color: color),
      ],
    ),
  );
}
