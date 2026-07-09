import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';

class CartProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final Map<String, int> _items = {}; // itemId -> quantity
  final Map<String, ShopItem> _itemDetails = {};

  final Map<String, double> _weightQuantities = {}; // itemId -> weight/quantity multiplier (e.g. 0.25, 0.5, 1.0, 2.0)
  final Map<String, String> _weightUnits = {}; // itemId -> unit name (e.g. kg, piece, dozen, g)

  Map<String, int> get items => _items;
  Map<String, double> get weightQuantities => _weightQuantities;
  Map<String, String> get weightUnits => _weightUnits;
  
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
      // Fetch delivery charge from app_settings or default to 20
      final settings = await _supabase.from('app_settings').select('value').eq('key', 'delivery_charge').maybeSingle();
      final deliveryFeeBase = (settings?['value'] as num? ?? 20.0).toDouble();
      final deliveryFee = deliveryType == 'Home Delivery' ? deliveryFeeBase : 0.0;
      final total = subTotal + deliveryFee;

      // 1. Prepare items for PG insertion
      final itemsJson = _items.entries.map((e) => {
        'id': e.key, 
        'qty': e.value, 
        'name': _itemDetails[e.key]?.name,
        'price': _itemDetails[e.key]?.discountPrice ?? _itemDetails[e.key]?.price,
        'weight_qty': _weightQuantities[e.key] ?? 1.0,
        'weight_unit': _weightUnits[e.key] ?? _itemDetails[e.key]?.unit ?? 'pcs',
      }).toList();

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
        // Call ENHANCED ATOMIC Checkout RPC
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

