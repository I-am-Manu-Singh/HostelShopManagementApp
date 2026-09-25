import 'package:flutter/foundation.dart';
import '../models/shop.dart';
import 'supabase_service.dart';
import 'pos_hardware_service.dart';

class PosCheckoutResult {
  final bool success;
  final String? invoiceNumber;
  final String? errorMessage;
  final PosReceiptData? receiptData;

  PosCheckoutResult({
    required this.success,
    this.invoiceNumber,
    this.errorMessage,
    this.receiptData,
  });
}

class PosSyncService {
  static final PosSyncService _instance = PosSyncService._internal();
  factory PosSyncService() => _instance;
  PosSyncService._internal();

  final _client = SupabaseService().client;

  /// Perform complete POS Checkout:
  /// 1. Decrements stock in shop_items
  /// 2. Records transaction in shop_orders
  /// 3. Updates student ledger/khata balance if student account used
  /// 4. Generates standard invoice number and returns printable receipt data
  Future<PosCheckoutResult> completePosCheckout({
    required List<OrderItem> items,
    required double subtotal,
    required double discount,
    required double cgst,
    required double sgst,
    required double total,
    required String paymentMode, // 'cash', 'upi', 'khata', 'card'
    String? customerId,
    String? customerName,
    String? customerPhone,
    double? tenderedAmount,
    double? changeAmount,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final cashierId = user?.id;
      final timestamp = DateTime.now();
      final invoiceNumber = "INV-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(7)}";

      // 1. If payment mode is student khata or student wallet, verify balance and deduct
      if ((paymentMode == 'khata' || paymentMode == 'wallet') && customerId != null) {
        final profileRes = await _client.from('profiles').select('balance, full_name').eq('id', customerId).maybeSingle();
        if (profileRes != null) {
          final double currentBal = (profileRes['balance'] as num?)?.toDouble() ?? 0.0;
          if (paymentMode == 'wallet' && currentBal < total) {
            return PosCheckoutResult(
              success: false,
              errorMessage: 'Insufficient student wallet balance (Current: ₹${currentBal.toStringAsFixed(2)}, Due: ₹${total.toStringAsFixed(2)})',
            );
          }
          // Deduct from student balance (can go negative up to hostel credit limit for khata, or direct wallet deduction)
          await _client.from('profiles').update({
            'balance': currentBal - total,
          }).eq('id', customerId);
        }
      }

      // 2. Insert into shop_orders with full POS metadata
      final orderData = {
        'user_id': (customerId != null && customerId.isNotEmpty) ? customerId : user?.id,
        'items': items.map((e) => e.toJson()).toList(),
        'total_price': total,
        'payment_status': 'Paid',
        'order_status': 'Delivered', // Immediate delivery on POS
        'created_at': timestamp.toIso8601String(),
        'delivery_location': 'POS Store Counter',
        'invoice_number': invoiceNumber,
        'payment_mode': paymentMode,
        'subtotal': subtotal,
        'discount': discount,
        'cgst': cgst,
        'sgst': sgst,
        'tendered_amount': tenderedAmount,
        'change_amount': changeAmount,
        'cashier_id': cashierId ?? user?.id,
        'is_pos_order': true,
      };

      try {
        await _client.from('shop_orders').insert(orderData);
      } catch (insertErr) {
        debugPrint('Insert shop_orders full schema failed: $insertErr, retrying with core columns...');
        try {
          // Fallback if some pos columns (e.g. is_pos_order or change_amount) are missing in older migrations
          final coreOrderData = {
            'user_id': (customerId != null && customerId.isNotEmpty) ? customerId : user?.id,
            'items': items.map((e) => e.toJson()).toList(),
            'total_price': total,
            'payment_status': 'Paid',
            'order_status': 'Delivered',
            'created_at': timestamp.toIso8601String(),
            'delivery_location': 'POS Store Counter',
            'payment_mode': paymentMode,
          };
          if (invoiceNumber.isNotEmpty) coreOrderData['invoice_number'] = invoiceNumber;
          await _client.from('shop_orders').insert(coreOrderData);
        } catch (coreErr) {
          debugPrint('Core shop_orders insert failed: $coreErr');
          return PosCheckoutResult(
            success: false,
            errorMessage: 'Database order save failed: $coreErr. Please run the SQL migration in testsqls/pos_module_schema_fix.sql',
          );
        }
      }

      // 3. Decrement Inventory stock
      for (final it in items) {
        try {
          final itemDoc = await _client.from('shop_items').select('stock_quantity').eq('id', it.id).maybeSingle();
          if (itemDoc != null) {
            final int currStock = (itemDoc['stock_quantity'] as num?)?.toInt() ?? 0;
            final int newStock = (currStock - it.qty).clamp(0, 999999);
            await _client.from('shop_items').update({'stock_quantity': newStock}).eq('id', it.id);
          }
        } catch (e) {
          debugPrint('Stock decrement error for ${it.id}: $e');
        }
      }

      // 4. Build receipt model
      final hardware = PosHardwareService();
      final receiptItems = items.map((i) => PosReceiptItem(
        name: i.name,
        quantity: i.qty,
        unitPrice: i.price,
        totalPrice: i.price * i.qty,
        hsn: i.hsnCode,
        taxPercent: i.taxRate,
      )).toList();

      final receiptData = PosReceiptData(
        storeName: hardware.storeName,
        storeAddress: hardware.storeAddress,
        storeGstin: hardware.storeGstin,
        storePhone: hardware.storePhone,
        invoiceNumber: invoiceNumber,
        dateTime: timestamp,
        cashierName: user?.email?.split('@').first ?? "Admin",
        customerName: customerName ?? (paymentMode == 'khata' ? "Student Khata" : "Walk-in Customer"),
        customerPhone: customerPhone,
        items: receiptItems,
        subtotal: subtotal,
        discount: discount,
        cgst: cgst,
        sgst: sgst,
        total: total,
        paymentMode: paymentMode,
        tenderedAmount: tenderedAmount,
        changeAmount: changeAmount,
        templateStyle: hardware.templateStyle,
        footerNote: hardware.footerNote,
      );

      return PosCheckoutResult(
        success: true,
        invoiceNumber: invoiceNumber,
        receiptData: receiptData,
      );
    } catch (e) {
      debugPrint("POS Checkout Error: $e");
      return PosCheckoutResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stock Inwarding (Goods Receipt Note / Purchase)
  Future<bool> inwardStock({
    required String itemId,
    required int addedQuantity,
    required double purchaseCost,
    double? newSellingPrice,
    String? vendorName,
    String? invoiceRef,
  }) async {
    try {
      final itemDoc = await _client.from('shop_items').select('stock_quantity, price').eq('id', itemId).maybeSingle();
      if (itemDoc == null) return false;

      final int currStock = (itemDoc['stock_quantity'] as num?)?.toInt() ?? 0;
      final int newStock = currStock + addedQuantity;

      final Map<String, dynamic> updateData = {
        'stock_quantity': newStock,
      };
      if (newSellingPrice != null && newSellingPrice > 0) {
        updateData['price'] = newSellingPrice;
      }

      await _client.from('shop_items').update(updateData).eq('id', itemId);

      // Attempt recording inventory transaction or procurement log
      try {
        await _client.from('procurements').insert({
          'item_name': itemId,
          'quantity': addedQuantity,
          'cost': purchaseCost * addedQuantity,
          'supplier_name': vendorName ?? 'Local Mandi / Vendor',
          'status': 'Received',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Table fallback safe
      }

      return true;
    } catch (e) {
      debugPrint("Inward stock error: $e");
      return false;
    }
  }
}
