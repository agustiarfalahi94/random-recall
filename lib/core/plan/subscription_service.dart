import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../auth/auth_service.dart';
import 'plan_service.dart';

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  static const String _apiKeyAndroid = 'goog_abc123...'; // Use your real key from the dashboard
  static const String _entitlementId = 'premium'; // The ID defined in RevenueCat Dashboard
  
  final _db = FirebaseFirestore.instance;
  bool _isConfigured = false;

  Future<void> init() async {
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

    // 1. Configure the SDK
    if (Platform.isAndroid) {
      // Guard against placeholder keys to avoid log spam
      if (_apiKeyAndroid.startsWith('goog_abc') || _apiKeyAndroid.contains('your_actual')) {
        debugPrint('SubscriptionService: API Key placeholder detected. Skipping RevenueCat init.');
        return;
      }
      await Purchases.configure(PurchasesConfiguration(_apiKeyAndroid));
      _isConfigured = true;
    }

    // 2. Set up listener for subscription status changes
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updatePremiumStatus(customerInfo);
    });

    // 3. Link current user if already logged in
    final user = AuthService.instance.currentUser;
    if (user != null && user.emailVerified) {
      await logIn(user.uid);
    }
  }

  /// Call this during login to link Firebase UID to RevenueCat
  Future<void> logIn(String uid) async {
    if (!_isConfigured) return;
    try {
      await Purchases.logIn(uid);
      final customerInfo = await Purchases.getCustomerInfo();
      await _updatePremiumStatus(customerInfo);
    } catch (e) {
      debugPrint('SubscriptionService: LogIn error: $e');
    }
  }

  /// Call this during logout
  Future<void> logOut() async {
    if (_isConfigured && !await Purchases.isAnonymous) {
      await Purchases.logOut().catchError((_) => null);
    }
    await PlanService.setPremiumStatus(false);
  }

  /// Fetches current offerings (configured in RevenueCat dashboard)
  Future<Offering?> getOffering() async {
    if (!_isConfigured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      debugPrint('SubscriptionService: Error fetching offerings: $e');
      return null;
    }
  }

  /// Initiates a purchase for a package
  Future<void> purchasePackage(Package package) async {
    if (!_isConfigured) return;
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      await _updatePremiumStatus(purchaseResult.customerInfo);
    } catch (e) {
      if (e is! PlatformException) rethrow;
      // Error code 1 is user cancellation
    }
  }

  Future<void> restorePurchases() async {
    if (!_isConfigured) return;
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _updatePremiumStatus(customerInfo);
    } catch (e) {
      debugPrint('SubscriptionService: Restore error: $e');
    }
  }

  Future<void> _updatePremiumStatus(CustomerInfo customerInfo) async {
    final user = AuthService.instance.currentUser;
    final isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
    
    // 1. Update local SharedPreferences
    await PlanService.setPremiumStatus(isPremium);

    // 2. Sync to Firestore
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'is_premium': isPremium,
          if (isPremium) 'premium_since': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('SubscriptionService: Firestore status sync failed: $e');
      }
    }
  }
}