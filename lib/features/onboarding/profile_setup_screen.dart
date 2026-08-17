import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/progress.dart';
import '../../state/app_flow_controller.dart';
import '../../state/progress_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  ExamTrack _track = ExamTrack.undecided;
  int _avatarId = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(progressControllerProvider.notifier)
        .updateProfile(
          username: _controller.text.trim(),
          avatarId: _avatarId,
          examTrack: _track,
        );
    ref.read(appFlowControllerProvider.notifier).markProfileReady();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.setupTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  l10n.setupUsernameLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: l10n.setupUsernameHint,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.setupUsernameRequired
                      : null,
                ),

                const SizedBox(height: 8),
                Text(l10n.profileAvatarLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                AvatarPicker(
                  selected: _avatarId,
                  onSelected: (id) => setState(() => _avatarId = id),
                ),

                const SizedBox(height: 28),
                Text(l10n.setupTrackLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  l10n.setupTrackOptional,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExamTrack.values
                      .map(
                        (track) => ChoiceChip(
                          label: Text(L10nMaps.examTrack(l10n, track)),
                          selected: _track == track,
                          onSelected: (_) => setState(() => _track = track),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 36),
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.commonContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: List.generate(AppPalette.avatarColors.length, (index) {
      final color = AppPalette.avatarColor(index);
      final isSelected = index == selected;
      return Semantics(
        selected: isSelected,
        button: true,
        child: GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : null,
          ),
        ),
      );
    }),
  );
}
