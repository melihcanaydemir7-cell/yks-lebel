import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/theme/app_palette.dart';
import '../../services/analytics_service.dart';
import '../../state/app_flow_controller.dart';
import '../../state/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.onboardingStarted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(analyticsProvider).logEvent(
      AnalyticsEvents.onboardingCompleted,
    );
    await ref.read(appFlowControllerProvider.notifier).completeOnboarding();
  }

  void _next(int pageCount) {
    if (_page >= pageCount - 1) {
      _finish();
      return;
    }
    ref.read(feedbackServiceProvider).tap();
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = <_OnboardingPageData>[
      _OnboardingPageData(
        emoji: '🎮',
        title: l10n.onboardingTitle1,
        body: l10n.onboardingBody1,
        color: AppPalette.primary,
      ),
      _OnboardingPageData(
        emoji: '🔥',
        title: l10n.onboardingTitle2,
        body: l10n.onboardingBody2,
        color: AppPalette.streak,
      ),
      _OnboardingPageData(
        emoji: '🏆',
        title: l10n.onboardingTitle3,
        body: l10n.onboardingBody3,
        color: AppPalette.gold,
      ),
    ];
    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLast ? null : _finish,
                child: Text(isLast ? '' : l10n.commonSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: pages[index]),
              ),
            ),
            _PageDots(count: pages.length, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: FilledButton(
                onPressed: () => _next(pages.length),
                child: Text(isLast ? l10n.onboardingCta : l10n.commonNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
  });

  final String emoji;
  final String title;
  final String body;
  final Color color;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 148,
          height: 148,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: data.color.withValues(alpha: 0.16),
          ),
          child: Text(data.emoji, style: const TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 40),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 14),
        Text(
          data.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(count, (i) {
      final active = i == index;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 26 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active
              ? AppPalette.primary
              : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }),
  );
}
