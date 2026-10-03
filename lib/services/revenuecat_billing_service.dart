import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum AppTier { free, pro, enterprise }

class RevenueCatBillingService {
  static final RevenueCatBillingService _instance = RevenueCatBillingService._internal();
  factory RevenueCatBillingService() => _instance;
  RevenueCatBillingService._internal();

  static const String _androidApiKey = "goog_cbl_hostel_default_key";
  static const String _iosApiKey = "appl_cbl_hostel_default_key";

  static const String entitlementPro = "pro_tier";
  static const String entitlementEnterprise = "enterprise_tier";

  final ValueNotifier<AppTier> currentTier = ValueNotifier<AppTier>(AppTier.free);

  Future<void> initialize({String? userId}) async {
    try {
      final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = userId,
      );

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateTierFromCustomerInfo(customerInfo);
      });

      final customerInfo = await Purchases.getCustomerInfo();
      _updateTierFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint("RevenueCat initialization notice: $e");
    }
  }

  void _updateTierFromCustomerInfo(CustomerInfo customerInfo) {
    if (customerInfo.entitlements.all[entitlementEnterprise]?.isActive ?? false) {
      currentTier.value = AppTier.enterprise;
    } else if (customerInfo.entitlements.all[entitlementPro]?.isActive ?? false) {
      currentTier.value = AppTier.pro;
    } else {
      currentTier.value = AppTier.free;
    }
  }

  bool get isPro => currentTier.value == AppTier.pro || currentTier.value == AppTier.enterprise;
  bool get isEnterprise => currentTier.value == AppTier.enterprise;

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Error fetching RevenueCat offerings: $e");
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _updateTierFromCustomerInfo(customerInfo);
      return isPro;
    } catch (e) {
      debugPrint("RevenueCat purchase error: $e");
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateTierFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint("RevenueCat restore error: $e");
    }
  }
}
