import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../auth/auth_service.dart';
import 'plan_service.dart';

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Monthly product ID defined in Google Play Console later
  static const String monthlyProductId = 'premium_monthly';

  final _db = FirebaseFirestore.instance;

  void init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('SubscriptionService: Error $error'),
    );
  }

  void dispose() {
    _subscription.cancel();
  }

  /// Fetches the product details from Google Play/App Store.
  Future<ProductDetails?> getMonthlyProduct() async {
    final bool available = await _iap.isAvailable();
    if (!available) return null;

    const Set<String> ids = {monthlyProductId};
    final response = await _iap.queryProductDetails(ids);

    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint('SubscriptionService: Product not found or error: ${response.error}');
      return null;
    }

    return response.productDetails.first;
  }

  /// Triggers the purchase flow for the premium subscription.
  Future<void> subscribe(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    // We use nonConsumable because it's a subscription
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restores previous purchases.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Handle pending state if needed
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('SubscriptionService: Purchase Error: ${purchase.error}');
      } else if (purchase.status == PurchaseStatus.purchased || 
                 purchase.status == PurchaseStatus.restored) {
        
        // 1. Verify and Deliver the content
        final bool valid = await _verifyPurchase(purchase);
        if (valid) {
          await _deliverPremiumStatus();
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // TODO: For production, implement server-side verification with Cloud Functions.
    // For now, we trust the device status.
    return true;
  }

  Future<void> _deliverPremiumStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // 1. Update local cache immediately
    await PlanService.setPremiumStatus(true);

    // 2. Update Firestore so all devices sync the status
    try {
      await _db.collection('users').doc(user.uid).set({
        'is_premium': true,
        'premium_since': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('SubscriptionService: Firestore updated to Premium.');
    } catch (e) {
      debugPrint('SubscriptionService: Failed to update Firestore: $e');
    }
  }
}