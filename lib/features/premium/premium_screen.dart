import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n_extension.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../services/analytics_service.dart';
import '../../services/billing_service.dart';
import '../../state/providers.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.premiumScreenViewed);
  }

  Future<void> _subscribe() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final analytics = ref.read(analyticsProvider);

    setState(() => _busy = true);
    await analytics.logEvent(AnalyticsEvents.subscriptionStarted);

    final outcome = await ref.read(billingServiceProvider).buyPremium();

    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case PurchaseOutcome.pending:
      case PurchaseOutcome.success:
        // The purchase stream reports the final state; success is announced by
        // the entitlement banner rebuilding.
        await analytics.logEvent(AnalyticsEvents.subscriptionSuccess);
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.error:
      case PurchaseOutcome.unavailable:
        await analytics.logEvent(
          AnalyticsEvents.subscriptionFailed,
          <String, Object?>{'reason': outcome.name},
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.premiumPurchaseFailed)),
        );
    }
  }

  Future<void> _restore() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final billing = ref.read(billingServiceProvider);
    await billing.restorePurchases();
    if (!mounted) return;
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

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final billing = ref.watch(billingServiceProvider);
    final status = ref
        .watch(premiumStatusProvider)
        .maybeWhen(data: (value) => value, orElse: () => billing.status);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppPalette.gold, AppPalette.streak],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.premiumTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.premiumSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),
          if (status.isPremium)
            AppCard(
              color: AppPalette.gold.withValues(alpha: 0.16),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    l10n.premiumActiveTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.premiumActiveBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _Benefit(text: l10n.premiumBenefitAds),
                  _Benefit(text: l10n.premiumBenefitStats),
                  _Benefit(text: l10n.premiumBenefitBadge),
                  _Benefit(text: l10n.premiumBenefitModes),
                ],
              ),
            ),

          if (status.state == PremiumState.gracePeriod) ...[
            const SizedBox(height: 12),
            _Notice(text: l10n.premiumGracePeriod, color: AppPalette.warning),
          ],
          if (status.state == PremiumState.expired) ...[
            const SizedBox(height: 12),
            _Notice(text: l10n.premiumExpired, color: AppPalette.danger),
          ],

          const SizedBox(height: 24),
          if (!status.isPremium)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
              onPressed: _busy || !status.storeAvailable ? null : _subscribe,
              child: _busy || status.purchasePending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      status.priceLabel == null
                          ? (status.storeAvailable
                                ? l10n.premiumCtaLoading
                                : l10n.premiumCtaUnavailable)
                          : l10n.premiumCtaPrice(status.priceLabel!),
                    ),
            ),
          const SizedBox(height: 8),
          TextButton(onPressed: _restore, child: Text(l10n.premiumRestore)),

          const SizedBox(height: 8),
          Text(
            l10n.premiumFreeNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.premiumRenewNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),
          // Wrap, not Row: both labels are long in Turkish and would overflow
          // a narrow phone side by side.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => _openUrl(AppConfig.privacyPolicyUrl),
                child: Text(l10n.premiumPrivacy),
              ),
              TextButton(
                onPressed: () => _openUrl(AppConfig.termsUrl),
                child: Text(l10n.premiumTerms),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppPalette.success),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    color: color.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}
