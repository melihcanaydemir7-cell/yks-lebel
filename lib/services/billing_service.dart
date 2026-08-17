import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/config/app_config.dart';
import 'local_store.dart';

/// Subscription lifecycle states the UI understands.
///
/// `gracePeriod` and `expired` cannot be distinguished reliably from the client
/// alone — Google Play only exposes them through the Play Developer API. The
/// states exist here so that adding server-side verification later is a change
/// in [BillingService._resolveState] and nowhere else. See README
/// "Google Play Billing Setup".
enum PremiumState { unknown, free, premium, gracePeriod, expired }

class PremiumStatus {
  const PremiumStatus({
    this.state = PremiumState.unknown,
    this.priceLabel,
    this.storeAvailable = false,
    this.purchasePending = false,
    this.lastError,
  });

  final PremiumState state;

  /// Localized price straight from Google Play. Never hardcode a price.
  final String? priceLabel;
  final bool storeAvailable;
  final bool purchasePending;
  final String? lastError;

  bool get isPremium =>
      state == PremiumState.premium || state == PremiumState.gracePeriod;

  bool get showsAds => !isPremium;

  PremiumStatus copyWith({
    PremiumState? state,
    String? priceLabel,
    bool? storeAvailable,
    bool? purchasePending,
    String? lastError,
    bool clearError = false,
  }) => PremiumStatus(
    state: state ?? this.state,
    priceLabel: priceLabel ?? this.priceLabel,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    purchasePending: purchasePending ?? this.purchasePending,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// Result of a purchase attempt, surfaced so the caller can log analytics.
enum PurchaseOutcome { success, cancelled, pending, error, unavailable }

class BillingService {
  BillingService(this._store, {InAppPurchase? iap}) : _iapOverride = iap;

  final LocalStore _store;

  /// Resolved lazily: `InAppPurchase.instance` throws on platforms without a
  /// billing implementation, and constructing this service must stay safe
  /// everywhere (tests, desktop, CI).
  final InAppPurchase? _iapOverride;
  InAppPurchase? _resolvedIap;

  InAppPurchase get _iap => _resolvedIap ??= _iapOverride ?? InAppPurchase.instance;

  final StreamController<PremiumStatus> _statusController =
      StreamController<PremiumStatus>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;

  PremiumStatus _status = const PremiumStatus();

  PremiumStatus get status => _status;
  Stream<PremiumStatus> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    // Trust the cached entitlement first so premium users are never shown an
    // ad while the store round-trips.
    _emit(
      _status.copyWith(
        state: _store.cachedPremium ? PremiumState.premium : PremiumState.free,
      ),
    );

    bool available;
    try {
      available = await _iap.isAvailable();
    } catch (error) {
      debugPrint('Billing unavailable: $error');
      available = false;
    }

    _emit(_status.copyWith(storeAvailable: available));
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object error) {
        _emit(_status.copyWith(lastError: error.toString()));
      },
    );

    await _loadProducts();
    await restorePurchases();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(
        AppConfig.billingProductIds,
      );
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        _emit(_status.copyWith(priceLabel: _product!.price));
      }
    } catch (error) {
      debugPrint('queryProductDetails failed: $error');
    }
  }

  Future<PurchaseOutcome> buyPremium() async {
    final product = _product;
    if (!_status.storeAvailable || product == null) {
      return PurchaseOutcome.unavailable;
    }
    _emit(_status.copyWith(purchasePending: true, clearError: true));
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _emit(_status.copyWith(purchasePending: false));
        return PurchaseOutcome.error;
      }
      return PurchaseOutcome.pending;
    } catch (error) {
      _emit(
        _status.copyWith(purchasePending: false, lastError: error.toString()),
      );
      return PurchaseOutcome.error;
    }
  }

  Future<void> restorePurchases() async {
    if (!_status.storeAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (error) {
      debugPrint('restorePurchases failed: $error');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!AppConfig.billingProductIds.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit(_status.copyWith(purchasePending: true));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantPremium();
        case PurchaseStatus.error:
          _emit(
            _status.copyWith(
              purchasePending: false,
              lastError: purchase.error?.message ?? 'purchase_error',
            ),
          );
        case PurchaseStatus.canceled:
          _emit(_status.copyWith(purchasePending: false));
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (error) {
          debugPrint('completePurchase failed: $error');
        }
      }
    }
  }

  Future<void> _grantPremium() async {
    await _store.setCachedPremium(true);
    _emit(
      _status.copyWith(
        state: PremiumState.premium,
        purchasePending: false,
        clearError: true,
      ),
    );
  }

  void _emit(PremiumStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
