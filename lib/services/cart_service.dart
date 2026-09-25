import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';
import 'organization_settings_service.dart';

class CartProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final Map<String, int> _items = {}; // itemId -> quantity
  final Map<String, ShopItem> _itemDetails = {};

  final Map<String, double> _weightQuantities = {}; // itemId -> weight/quantity multiplier (e.g. 0.25, 0.5, 1.0, 2.0)
  final Map<String, String> _weightUnits = {}; // itemId -> unit name (e.g. kg, piece, dozen, g)

  Map<String, int> get items => _items;
  Map<String, double> get weightQuantities => _weightQuantities;
  Map<String, String> get weightUnits => _weightUnits;

  // Active Logistics Rules & Festival Offers
  List<Map<String, dynamic>> _logisticsRules = [];
  double _baseDeliveryFee = 20.0;

  List<Map<String, dynamic>> get logisticsRules => _logisticsRules;
  double get baseDeliveryFee => _baseDeliveryFee;

  /// Loads current delivery charge and festival/logistics offers from Supabase
  Future<void> fetchLogisticsAndOffers() async {
    try {
      final res = await _supabase.from('app_settings').select('key, value').inFilter('key', ['delivery_charge', 'logistics_rules']);
      for (var s in res) {
        if (s['key'] == 'delivery_charge' && s['value'] != null) {
          _baseDeliveryFee = double.tryParse(s['value'].toString()) ?? 20.0;
        } else if (s['key'] == 'logistics_rules' && s['value'] != null) {
          _logisticsRules = OrganizationSettingsService.parseRules(s['value']);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching logistics rules: $e');
    }
  }

  /// Calculates net adjustment from active rules considering date ranges & filters
  double calculateAdjustment({String deliveryType = 'Home Delivery', String userType = 'domestic'}) {
    double adjustment = 0.0;
    final now = DateTime.now();

    for (var r in _logisticsRules) {
      if (r['enabled'] != true) continue;

      // 1. Time Frame Filter
      if (r['start_date'] != null && r['start_date'].toString().trim().isNotEmpty) {
        final start = DateTime.tryParse(r['start_date'].toString());
        if (start != null && now.isBefore(start)) continue;
      }
      if (r['end_date'] != null && r['end_date'].toString().trim().isNotEmpty) {
        final end = DateTime.tryParse(r['end_date'].toString());
        if (end != null && now.isAfter(end)) continue;
      }

      // 2. Target Category / Channel Filter
      final appliesTo = r['applies_to']?.toString() ?? 'all';
      final matchesChannel = appliesTo == 'all' || 
          (appliesTo == 'delivery_only' && deliveryType == 'Home Delivery') ||
          (appliesTo == 'takeaway_only' && (deliveryType == 'Pickup' || deliveryType == 'Takeaway')) ||
          (appliesTo == userType);

      if (matchesChannel) {
        final amt = (r['amount'] as num? ?? 0.0).toDouble();
        final type = r['type']?.toString();
        if (type == 'discount') {
          adjustment -= amt;
        } else {
          adjustment += amt;
        }
      }
    }
    return adjustment;
  }
  
  double get totalAmount {
    double total = 0;
    _items.forEach((id, qty) {
      final item = _itemDetails[id];
      if (item != null) {
        final price = item.discountPrice ?? item.price;
        final multiplier = _weightQuantities[id] ?? 1.0;
        total += price * qty * multiplier;
      }
    });
    return total;
  }

  int get itemCount => _items.values.fold(0, (sum, qty) => sum + qty);

  void addItem(ShopItem item, {double multiplier = 1.0, String? unit}) {
    if (item.stockQuantity <= 0) return;
    
    int currentInCart = _items[item.id] ?? 0;
    if (currentInCart >= item.stockQuantity) return;

    if (_items.containsKey(item.id)) {
      _items[item.id] = _items[item.id]! + 1;
    } else {
      _items[item.id] = 1;
      _itemDetails[item.id] = item;
      _weightQuantities[item.id] = multiplier;
      _weightUnits[item.id] = unit ?? item.unit;
    }
    notifyListeners();
  }

  void updateWeightOrUnit(String itemId, double multiplier, String unit) {
    if (_items.containsKey(itemId)) {
      _weightQuantities[itemId] = multiplier;
      _weightUnits[itemId] = unit;
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    if (!_items.containsKey(itemId)) return;
    if (_items[itemId]! > 1) {
      _items[itemId] = _items[itemId]! - 1;
    } else {
      _items.remove(itemId);
      _itemDetails.remove(itemId);
      _weightQuantities.remove(itemId);
      _weightUnits.remove(itemId);
    }
    notifyListeners();
  }

  void updateQuantity(String itemId, int delta) {
    if (!_items.containsKey(itemId)) return;
    int newQty = _items[itemId]! + delta;
    if (newQty <= 0) {
      _items.remove(itemId);
      _itemDetails.remove(itemId);
      _weightQuantities.remove(itemId);
      _weightUnits.remove(itemId);
    } else {
      _items[itemId] = newQty;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _itemDetails.clear();
    notifyListeners();
  }

  Future<String?> checkout({
    required String deliveryType,
    required String paymentMethod,
    String? upiScreenshotUrl,
    String? deliveryAddress,
    String? phoneNo,
    String? altPhoneNo,
    String? emergencyName,
    String? emergencyRelation,
    String? emergencyPhone,
    String? instructions,
    bool isBooking = false,
    DateTime? bookingDate,
    double advancePaid = 0.0,
    String userType = 'domestic',
    String? deliveryLocation,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'USER SESSION EXPIRED';

      final subTotal = totalAmount;
      // Fetch fresh settings and calculate special logistics rules / festival offers
      await fetchLogisticsAndOffers();
      final deliveryFee = deliveryType == 'Home Delivery' ? _baseDeliveryFee : 0.0;
      final specialAdjustment = calculateAdjustment(deliveryType: deliveryType, userType: userType);

      final calculatedTotal = subTotal + deliveryFee + specialAdjustment;
      final total = calculatedTotal > 0 ? calculatedTotal : 0.0;


      // 1. Prepare items for PG insertion
      final itemsJson = _items.entries.map((e) => {
        'id': e.key, 
        'qty': e.value, 
        'name': _itemDetails[e.key]?.name,
        'price': _itemDetails[e.key]?.discountPrice ?? _itemDetails[e.key]?.price,
        'weight_qty': _weightQuantities[e.key] ?? 1.0,
        'weight_unit': _weightUnits[e.key] ?? _itemDetails[e.key]?.unit ?? 'pcs',
      }).toList();

      try {
        if (isBooking) {
          // Direct insertion for booking to avoid RPC restrictions
          await _supabase.from('shop_orders').insert({
            'user_id': user.id,
            'items': itemsJson,
            'total_price': total,
            'payment_status': paymentMethod == 'Wallet' ? 'Paid' : 'Pending',
            'order_status': 'Placed',
            'is_booking': true,
            'booking_date': bookingDate?.toIso8601String(),
            'advance_paid': advancePaid,
            'user_type': userType,
            'delivery_address': deliveryAddress,
            'delivery_location': deliveryLocation,
            'phone_no': phoneNo,
          });
        } else {
          // Try atomic checkout RPC
          await _supabase.rpc('place_shop_order', params: {
            'input_user_id': user.id,
            'input_total': total,
            'input_items': itemsJson,
            'input_delivery_type': deliveryType,
            'input_payment_method': paymentMethod,
            'input_address': deliveryAddress,
            'input_phone': phoneNo,
            'input_alt_phone': altPhoneNo,
            'input_screenshot': upiScreenshotUrl,
            'input_emergency_name': emergencyName,
            'input_emergency_relation': emergencyRelation,
            'input_emergency_phone': emergencyPhone,
            'input_instructions': instructions,
          });
        }
      } catch (rpcErr) {
        // Fallback: If RPC place_shop_order is not defined, execute direct database transaction insert
        debugPrint('RPC place_shop_order not found. Executing client-side fallback insert. Error: $rpcErr');
        try {
          await _supabase.from('shop_orders').insert({
            'user_id': user.id,
            'items': itemsJson,
            'total_price': total,
            'payment_method': paymentMethod,
            'payment_status': paymentMethod == 'Wallet' ? 'Paid' : 'Pending',
            'order_status': 'Placed',
            'is_booking': false,
            'delivery_address': deliveryAddress,
            'phone_no': phoneNo,
            'upi_screenshot_url': upiScreenshotUrl,
            'instructions': instructions,
          });
        } catch (colErr) {
          // If 'instructions' column is missing from schema cache, retry without it
          debugPrint('Insert with instructions failed, retrying without: $colErr');
          await _supabase.from('shop_orders').insert({
            'user_id': user.id,
            'items': itemsJson,
            'total_price': total,
            'payment_method': paymentMethod,
            'payment_status': paymentMethod == 'Wallet' ? 'Paid' : 'Pending',
            'order_status': 'Placed',
            'is_booking': false,
            'delivery_address': deliveryAddress,
            'phone_no': phoneNo,
            'upi_screenshot_url': upiScreenshotUrl,
          });
        }

        // Deduct wallet balance client-side if payment method is Wallet
        if (paymentMethod == 'Wallet') {
          final profileRes = await _supabase.from('profiles').select('balance').eq('id', user.id).single();
          final currentBalance = (profileRes['balance'] as num? ?? 0.0).toDouble();
          if (currentBalance < total) {
            throw 'INSUFFICIENT_FUNDS';
          }
          await _supabase.from('profiles').update({
            'balance': currentBalance - total
          }).eq('id', user.id);
        }
      }

      _weightQuantities.clear();
      _weightUnits.clear();
      clearCart();
      return null;
    } catch (e) {
      debugPrint('Checkout error: $e');
      String msg = e.toString();
      if (msg.contains('INSUFFICIENT_FUNDS')) return 'INSUFFICIENT_FUNDS';
      return msg;
    }
  }

  ShopItem? getItemDetail(String id) => _itemDetails[id];
}

