import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n_extension.dart';
import '../core/theme/app_palette.dart';
import '../state/providers.dart';
import 'app_router.dart';

/// Bottom-navigation scaffold. "Çalış" is emphasised with a filled indicator so
/// the primary action reads first.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const List<String> _tabs = <String>[
    AppRoutes.home,
    AppRoutes.study,
    AppRoutes.league,
    AppRoutes.profile,
  ];

  int get _index {
    final index = _tabs.indexWhere((tab) => location.startsWith(tab));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          ref.read(feedbackServiceProvider).tap();
          context.go(_tabs[index]);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: _StudyIcon(selected: _index == 1),
            selectedIcon: _StudyIcon(selected: true),
            label: l10n.navStudy,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events_rounded),
            label: l10n.navLeague,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

class _StudyIcon extends StatelessWidget {
  const _StudyIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppPalette.primary, AppPalette.secondary],
      ),
      borderRadius: BorderRadius.circular(999),
      boxShadow: selected
          ? [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
  );
}
