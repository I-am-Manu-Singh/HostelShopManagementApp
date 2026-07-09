// lib/services/mandi_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mandi.dart';

class MandiService {
  final _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ─────────────────────────────────────────────
  // PROFILE HELPERS
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchMyMandiProfile() async {
    try {
      final uid = currentUserId;
      if (uid == null) return null;
      return await _client
          .from('profiles')
          .select('id, full_name, phone_no, role, delivery_address, delivery_location, user_type')
          .eq('id', uid)
          .maybeSingle();
    } catch (e) {
      debugPrint('MandiService.fetchMyMandiProfile: $e');
      return null;
    }
  }

  Future<bool> updateMandiProfile({
    required String deliveryAddress,
    required String deliveryLocation,
    required String userType,
  }) async {
    try {
      final uid = currentUserId;
      if (uid == null) return false;
      await _client.from('profiles').update({
        'delivery_address': deliveryAddress,
        'delivery_location': deliveryLocation,
        'user_type': userType,
      }).eq('id', uid);
      return true;
    } catch (e) {
      debugPrint('MandiService.updateMandiProfile: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PRODUCTS
  // ─────────────────────────────────────────────

  Future<List<MandiProduct>> fetchProducts({String? category}) async {
    try {
      var query = _client
          .from('mandi_products')
          .select()
          .eq('is_available', true);
      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      final res = await query.order('display_order');
      return (res as List).map((e) => MandiProduct.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MandiService.fetchProducts: $e');
      return [];
    }
  }

  Future<MandiProduct?> fetchProductById(String id) async {
    try {
      final res = await _client
          .from('mandi_products')
          .select()
          .eq('id', id)
          .maybeSingle();
      return res != null ? MandiProduct.fromJson(res) : null;
    } catch (e) {
      debugPrint('MandiService.fetchProductById: $e');
      return null;
    }
  }

  Future<bool> createProduct(MandiProduct product) async {
    try {
      await _client.from('mandi_products').insert(product.toJson());
      return true;
    } catch (e) {
      debugPrint('MandiService.createProduct: $e');
      return false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('mandi_products').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('MandiService.updateProduct: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _client.from('mandi_products').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('MandiService.deleteProduct: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // RATES
  // ─────────────────────────────────────────────

  /// Returns price for product on a given date; null if not set
  Future<double?> fetchRateForDate(String productId, DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final res = await _client
          .from('mandi_rates')
          .select('price_per_unit')
          .eq('product_id', productId)
          .eq('rate_date', dateStr)
          .maybeSingle();
      if (res == null) return null;
      return (res['price_per_unit'] as num?)?.toDouble();
    } catch (e) {
      debugPrint('MandiService.fetchRateForDate: $e');
      return null;
    }
  }

  /// Fetch today's rate map: productId → price
  Future<Map<String, double>> fetchTodayRates() async {
    try {
      final todayStr =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final res = await _client
          .from('mandi_rates')
          .select('product_id, price_per_unit')
          .eq('rate_date', todayStr);
      final map = <String, double>{};
      for (final row in (res as List)) {
        map[row['product_id']] =
            (row['price_per_unit'] as num?)?.toDouble() ?? 0.0;
      }
      return map;
    } catch (e) {
      debugPrint('MandiService.fetchTodayRates: $e');
      return {};
    }
  }

  Future<List<MandiRate>> fetchRatesForProduct(String productId) async {
    try {
      final res = await _client
          .from('mandi_rates')
          .select()
          .eq('product_id', productId)
          .order('rate_date', ascending: false)
          .limit(30);
      return (res as List).map((e) => MandiRate.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MandiService.fetchRatesForProduct: $e');
      return [];
    }
  }

  Future<bool> setRate({
    required String productId,
    required DateTime date,
    required double price,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _client.from('mandi_rates').upsert({
        'product_id': productId,
        'rate_date': dateStr,
        'price_per_unit': price,
        'created_by': currentUserId,
      }, onConflict: 'product_id,rate_date');
      return true;
    } catch (e) {
      debugPrint('MandiService.setRate: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // BOOKINGS
  // ─────────────────────────────────────────────

  Future<String?> createBooking({
    required DateTime bookingDate,
    required String deliveryAddress,
    required String deliveryLocation,
    required String userType,
    required double advancePaid,
    required double totalAmount,
    required List<MandiCartItem> items,
    String? notes,
    String? customerName,
    String? customerPhone,
  }) async {
    try {
      final uid = currentUserId;
      if (uid == null) return null;

      final dateStr =
          '${bookingDate.year}-${bookingDate.month.toString().padLeft(2, '0')}-${bookingDate.day.toString().padLeft(2, '0')}';

      // 1. Insert booking
      final bookingRes = await _client
          .from('mandi_bookings')
          .insert({
            'customer_id': uid,
            'customer_name': customerName,
            'customer_phone': customerPhone,
            'booking_date': dateStr,
            'delivery_address': deliveryAddress,
            'delivery_location': deliveryLocation,
            'user_type': userType,
            'advance_paid': advancePaid,
            'total_amount': totalAmount,
            'notes': notes,
            'status': 'pending',
          })
          .select('id')
          .single();

      final bookingId = bookingRes['id'] as String;

      // 2. Insert booking items
      final itemsData = items
          .map((item) => {
                'booking_id': bookingId,
                'product_id': item.product.id,
                'product_name': item.product.name,
                'quantity': item.quantity,
                'unit': item.product.unit,
                'rate_per_unit': item.ratePerUnit,
                'subtotal': item.subtotal,
              })
          .toList();
      await _client.from('mandi_booking_items').insert(itemsData);

      return bookingId;
    } catch (e) {
      debugPrint('MandiService.createBooking: $e');
      return null;
    }
  }

  Future<List<MandiBooking>> fetchMyBookings() async {
    try {
      final uid = currentUserId;
      if (uid == null) return [];
      final res = await _client
          .from('mandi_bookings')
          .select('*, mandi_booking_items(*)')
          .eq('customer_id', uid)
          .order('created_at', ascending: false);
      return (res as List).map((e) => MandiBooking.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MandiService.fetchMyBookings: $e');
      return [];
    }
  }

  /// Admin: fetch all bookings
  Future<List<MandiBooking>> fetchAllBookings({String? status}) async {
    try {
      var query = _client
          .from('mandi_bookings')
          .select('*, mandi_booking_items(*)');
      if (status != null) {
        query = query.eq('status', status);
      }
      final res = await query.order('created_at', ascending: false);
      return (res as List).map((e) => MandiBooking.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MandiService.fetchAllBookings: $e');
      return [];
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _client
          .from('mandi_bookings')
          .update({'status': status})
          .eq('id', bookingId);
      return true;
    } catch (e) {
      debugPrint('MandiService.updateBookingStatus: $e');
      return false;
    }
  }

  Future<bool> assignDeliveryPartner(
      String bookingId, String partnerId) async {
    try {
      await _client.from('mandi_bookings').update({
        'assigned_delivery_partner': partnerId,
        'status': 'out_for_delivery',
      }).eq('id', bookingId);

      // Also create delivery record
      await _client.from('mandi_deliveries').upsert({
        'booking_id': bookingId,
        'delivery_partner_id': partnerId,
        'status': 'assigned',
      });
      return true;
    } catch (e) {
      debugPrint('MandiService.assignDeliveryPartner: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PURCHASE ORDERS
  // ─────────────────────────────────────────────

  Future<bool> createPurchaseOrder({
    required String productName,
    required String productId,
    required double quantity,
    required String unit,
    required double ratePerUnit,
    required double totalAmount,
    String? sellerId,
    String? sellerName,
    String? sellerPhone,
    String? photoUrl,
    String? notes,
  }) async {
    try {
      await _client.from('mandi_purchase_orders').insert({
        'created_by': currentUserId,
        'seller_id': sellerId,
        'seller_name': sellerName,
        'seller_phone': sellerPhone,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'rate_per_unit': ratePerUnit,
        'total_amount': totalAmount,
        'photo_url': photoUrl,
        'notes': notes,
        'status': 'draft',
      });
      return true;
    } catch (e) {
      debugPrint('MandiService.createPurchaseOrder: $e');
      return false;
    }
  }

  Future<List<MandiPurchaseOrder>> fetchPurchaseOrders() async {
    try {
      final res = await _client
          .from('mandi_purchase_orders')
          .select()
          .order('created_at', ascending: false);
      return (res as List)
          .map((e) => MandiPurchaseOrder.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('MandiService.fetchPurchaseOrders: $e');
      return [];
    }
  }

  Future<List<MandiPurchaseOrder>> fetchMyPurchaseOrders() async {
    try {
      final uid = currentUserId;
      if (uid == null) return [];
      final res = await _client
          .from('mandi_purchase_orders')
          .select()
          .eq('seller_id', uid)
          .order('created_at', ascending: false);
      return (res as List)
          .map((e) => MandiPurchaseOrder.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('MandiService.fetchMyPurchaseOrders: $e');
      return [];
    }
  }

  Future<bool> updatePurchaseOrderStatus(String id, String status) async {
    try {
      await _client
          .from('mandi_purchase_orders')
          .update({'status': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('MandiService.updatePurchaseOrderStatus: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // DELIVERIES
  // ─────────────────────────────────────────────

  Future<List<MandiDelivery>> fetchMyDeliveries() async {
    try {
      final uid = currentUserId;
      if (uid == null) return [];
      final res = await _client
          .from('mandi_deliveries')
          .select()
          .eq('delivery_partner_id', uid)
          .order('assigned_at', ascending: false);
      return (res as List).map((e) => MandiDelivery.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MandiService.fetchMyDeliveries: $e');
      return [];
    }
  }

  Future<bool> updateDeliveryStatus(String deliveryId, String status) async {
    try {
      final data = <String, dynamic>{'status': status};
      if (status == 'picked_up') data['picked_up_at'] = DateTime.now().toIso8601String();
      if (status == 'delivered') data['delivered_at'] = DateTime.now().toIso8601String();
      await _client.from('mandi_deliveries').update(data).eq('id', deliveryId);
      return true;
    } catch (e) {
      debugPrint('MandiService.updateDeliveryStatus: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // STORAGE (photo upload for POs)
  // ─────────────────────────────────────────────

  Future<String?> uploadPurchaseOrderPhoto(File file) async {
    try {
      final fileName = 'po_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage
          .from('mandi-assets')
          .upload(fileName, file);
      final url = _client.storage.from('mandi-assets').getPublicUrl(fileName);
      return url;
    } catch (e) {
      debugPrint('MandiService.uploadPurchaseOrderPhoto: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN: fetch delivery partners from profiles
  // ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDeliveryPartners() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, phone_no')
          .eq('role', 'delivery_partner');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('MandiService.fetchDeliveryPartners: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSellers() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, phone_no')
          .eq('role', 'farmer_seller');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('MandiService.fetchSellers: $e');
      return [];
    }
  }
}
