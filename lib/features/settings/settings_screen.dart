import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n_extension.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../routing/app_router.dart';
import '../../services/notification_service.dart';
import '../../state/app_flow_controller.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          SectionHeader(title: l10n.settingsSectionApp),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.notificationsEnabled,
                  title: Text(l10n.settingsNotifications),
                  subtitle: Text(l10n.settingsNotificationsBody),
                  onChanged: (value) =>
                      _toggleNotifications(context, ref, value),
                ),
                ListTile(
                  enabled: settings.notificationsEnabled,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(l10n.settingsReminderTime),
                  trailing: Text(
                    settings.reminderTime.format(context),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  onTap: settings.notificationsEnabled
                      ? () => _pickTime(context, ref)
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.settingsTheme),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (mode) {
                      if (mode != null) controller.setThemeMode(mode);
                    },
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(l10n.settingsThemeSystem),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(l10n.settingsThemeLight),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(l10n.settingsThemeDark),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: settings.soundEnabled,
                  title: Text(l10n.settingsSound),
                  onChanged: controller.setSoundEnabled,
                ),
                SwitchListTile(
                  value: settings.hapticsEnabled,
                  title: Text(l10n.settingsHaptics),
                  onChanged: controller.setHapticsEnabled,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SectionHeader(title: l10n.settingsSectionAccount),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: Text(l10n.settingsRestore),
                  onTap: () => _restore(context, ref),
                ),
                if (user.isSignedIn) ...[
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(l10n.settingsSignOut),
                    onTap: () => _signOut(context, ref),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n.settingsDeleteAccount,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ] else if (ref.watch(authAvailableProvider))
                  ListTile(
                    leading: const Icon(Icons.login_rounded),
                    title: Text(l10n.settingsSignIn),
                    onTap: () =>
                        ref.read(appFlowControllerProvider.notifier).resetAuthGate(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SectionHeader(title: l10n.settingsSectionAbout),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(l10n.premiumTitle),
                  onTap: () => context.push(AppRoutes.premium),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.settingsPrivacy),
                  onTap: () => _openUrl(context, AppConfig.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.settingsTerms),
                  onTap: () => _openUrl(context, AppConfig.termsUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: Text(l10n.settingsContact),
                  subtitle: const Text(AppConfig.supportEmail),
                  onTap: () => _openUrl(
                    context,
                    'mailto:${AppConfig.supportEmail}'
                    '?subject=${Uri.encodeComponent(AppConfig.appName)}',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: ref
                .watch(_appVersionProvider)
                .maybeWhen(
                  data: (version) => Text(
                    l10n.settingsVersion(version),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(settingsControllerProvider.notifier);
    final notifications = ref.read(notificationServiceProvider);

    if (!enabled) {
      await controller.setNotificationsEnabled(false);
      await notifications.cancelReminder();
      return;
    }

    await notifications.initialize(channelName: l10n.notificationChannelName);
    final granted = await notifications.requestPermission();
    if (!granted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsNotificationDenied)),
      );
      return;
    }

    await controller.setNotificationsEnabled(true);
    await _scheduleReminder(l10n, notifications, ref);
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final settings = ref.read(settingsControllerProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked == null) return;

    await ref.read(settingsControllerProvider.notifier).setReminderTime(picked);
    await _scheduleReminder(l10n, ref.read(notificationServiceProvider), ref);
  }

  Future<void> _scheduleReminder(
    L10n l10n,
    NotificationService notifications,
    WidgetRef ref,
  ) async {
    final settings = ref.read(settingsControllerProvider);
    await notifications.scheduleDailyReminder(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      title: l10n.notificationTitle,
      body: l10n.notificationBody,
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final billing = ref.read(billingServiceProvider);
    await billing.restorePurchases();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          billing.status.isPremium
              ? l10n.premiumRestoreSuccess
              : l10n.premiumRestoreNone,
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.settingsSignOutTitle,
      body: l10n.settingsSignOutBody,
      confirmLabel: l10n.settingsSignOut,
    );
    if (!confirmed) return;

    await ref.read(authServiceProvider).signOut();
    await ref.read(appFlowControllerProvider.notifier).resetAuthGate();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.settingsDeleteTitle,
      body: l10n.settingsDeleteBody,
      confirmLabel: l10n.settingsDeleteAccount,
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(authServiceProvider).deleteAccount();
      await ref.read(progressControllerProvider.notifier).resetLocalProgress();
      await ref.read(appFlowControllerProvider.notifier).resetAuthGate();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteSuccess)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteFailed)),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: destructive
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsLinkFailed)));
    }
  }
}
