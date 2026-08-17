import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/l10n_maps.dart';
import '../../data/models/progress.dart';
import '../../state/progress_controller.dart';
import '../onboarding/profile_setup_screen.dart';

Future<void> showEditProfileSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const _EditProfileSheet(),
);

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _controller;
  late int _avatarId;
  late ExamTrack _track;

  @override
  void initState() {
    super.initState();
    final progress = ref.read(progressControllerProvider);
    _controller = TextEditingController(text: progress.username);
    _avatarId = progress.avatarId;
    _track = progress.examTrack;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(progressControllerProvider.notifier)
        .updateProfile(username: name, avatarId: _avatarId, examTrack: _track);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileEditTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLength: 24,
              decoration: InputDecoration(labelText: l10n.authUsername),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileAvatarLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            AvatarPicker(
              selected: _avatarId,
              onSelected: (id) => setState(() => _avatarId = id),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.setupTrackLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
          ],
        ),
      ),
    );
  }
}
