import 'package:flutter/services.dart';

/// Haptics and UI sounds, both gated behind user settings.
class FeedbackService {
  FeedbackService({this.hapticsEnabled = true, this.soundEnabled = true});

  final bool hapticsEnabled;
  final bool soundEnabled;

  Future<void> correct() async {
    if (hapticsEnabled) await HapticFeedback.lightImpact();
    if (soundEnabled) await SystemSound.play(SystemSoundType.click);
  }

  Future<void> wrong() async {
    if (hapticsEnabled) await HapticFeedback.heavyImpact();
  }

  Future<void> tap() async {
    if (hapticsEnabled) await HapticFeedback.selectionClick();
  }

  Future<void> celebrate() async {
    if (hapticsEnabled) {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.mediumImpact();
    }
  }
}
