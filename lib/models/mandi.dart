// lib/models/mandi.dart
// Data models for the Mandi Mart module

class MandiProduct {
  final String id;
  final String name;
  final String category; // Sabji, Fruit, Kiryana
  final String unit; // kg, piece, dozen, litre, bundle, gram
  final String? imageUrl;
  final String? description;
  final bool isAvailable;
  final int displayOrder;
  final DateTime createdAt;

  // Loaded on-demand (not stored in DB column)
  double? todayRate;

  MandiProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.imageUrl,
    this.description,
    this.isAvailable = true,
    this.displayOrder = 0,
    required this.createdAt,
    this.todayRate,
  });

  factory MandiProduct.fromJson(Map<String, dynamic> json) => MandiProduct(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? 'Sabji',
        unit: json['unit'] ?? 'kg',
        imageUrl: json['image_url'],
        description: json['description'],
        isAvailable: json['is_available'] ?? true,
        displayOrder: json['display_order'] ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'unit': unit,
        'image_url': imageUrl,
        'description': description,
        'is_available': isAvailable,
        'display_order': displayOrder,
      };
}

class MandiRate {
  final String id;
  final String productId;
  final DateTime rateDate;
  final double pricePerUnit;
  final double minQty;
  final DateTime createdAt;

  MandiRate({
    required this.id,
    required this.productId,
    required this.rateDate,
    required this.pricePerUnit,
    this.minQty = 0,
    required this.createdAt,
  });

  factory MandiRate.fromJson(Map<String, dynamic> json) => MandiRate(
        id: json['id'] ?? '',
        productId: json['product_id'] ?? '',
        rateDate: DateTime.tryParse(json['rate_date'] ?? '') ?? DateTime.now(),
        pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
        minQty: (json['min_qty'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class MandiBookingItem {
  final String id;
  final String bookingId;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double ratePerUnit;
  final double subtotal;

  MandiBookingItem({
    required this.id,
    required this.bookingId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.ratePerUnit,
    required this.subtotal,
  });

  factory MandiBookingItem.fromJson(Map<String, dynamic> json) =>
      MandiBookingItem(
        id: json['id'] ?? '',
        bookingId: json['booking_id'] ?? '',
        productId: json['product_id'] ?? '',
        productName: json['product_name'] ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] ?? 'kg',
        ratePerUnit: (json['rate_per_unit'] as num?)?.toDouble() ?? 0.0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'rate_per_unit': ratePerUnit,
        'subtotal': subtotal,
      };
}

class MandiBooking {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final DateTime bookingDate;
  final String? deliveryAddress;
  final String? deliveryLocation;
  final String userType;
  final String status;
  final double advancePaid;
  final double? totalAmount;
  final String? notes;
  final String? assignedDeliveryPartner;
  final DateTime createdAt;
  final List<MandiBookingItem> items;

  MandiBooking({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.bookingDate,
    this.deliveryAddress,
    this.deliveryLocation,
    this.userType = 'domestic',
    this.status = 'pending',
    this.advancePaid = 0,
    this.totalAmount,
    this.notes,
    this.assignedDeliveryPartner,
    required this.createdAt,
    this.items = const [],
  });

  factory MandiBooking.fromJson(Map<String, dynamic> json) => MandiBooking(
        id: json['id'] ?? '',
        customerId: json['customer_id'] ?? '',
        customerName: json['customer_name'],
        customerPhone: json['customer_phone'],
        bookingDate:
            DateTime.tryParse(json['booking_date'] ?? '') ?? DateTime.now(),
        deliveryAddress: json['delivery_address'],
        deliveryLocation: json['delivery_location'],
        userType: json['user_type'] ?? 'domestic',
        status: json['status'] ?? 'pending',
        advancePaid: (json['advance_paid'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['total_amount'] as num?)?.toDouble(),
        notes: json['notes'],
        assignedDeliveryPartner: json['assigned_delivery_partner'],
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        items: (json['mandi_booking_items'] as List?)
                ?.map((e) => MandiBookingItem.fromJson(e))
                .toList() ??
            [],
      );
}

class MandiPurchaseOrder {
  final String id;
  final String createdBy;
  final String? sellerId;
  final String? sellerName;
  final String? sellerPhone;
  final String? productId;
  final String productName;
  final double quantity;
  final String unit;
  final double ratePerUnit;
  final double totalAmount;
  final String? photoUrl;
  final String status;
  final String? notes;
  final DateTime orderDate;
  final DateTime createdAt;

  MandiPurchaseOrder({
    required this.id,
    required this.createdBy,
    this.sellerId,
    this.sellerName,
    this.sellerPhone,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.ratePerUnit,
    required this.totalAmount,
    this.photoUrl,
    this.status = 'draft',
    this.notes,
    required this.orderDate,
    required this.createdAt,
  });

  factory MandiPurchaseOrder.fromJson(Map<String, dynamic> json) =>
      MandiPurchaseOrder(
        id: json['id'] ?? '',
        createdBy: json['created_by'] ?? '',
        sellerId: json['seller_id'],
        sellerName: json['seller_name'],
        sellerPhone: json['seller_phone'],
        productId: json['product_id'],
        productName: json['product_name'] ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] ?? 'kg',
        ratePerUnit: (json['rate_per_unit'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
        photoUrl: json['photo_url'],
        status: json['status'] ?? 'draft',
        notes: json['notes'],
        orderDate:
            DateTime.tryParse(json['order_date'] ?? '') ?? DateTime.now(),
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class MandiDelivery {
  final String id;
  final String bookingId;
  final String? deliveryPartnerId;
  final String status;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? notes;
  final DateTime assignedAt;

  MandiDelivery({
    required this.id,
    required this.bookingId,
    this.deliveryPartnerId,
    this.status = 'assigned',
    this.pickedUpAt,
    this.deliveredAt,
    this.notes,
    required this.assignedAt,
  });

  factory MandiDelivery.fromJson(Map<String, dynamic> json) => MandiDelivery(
        id: json['id'] ?? '',
        bookingId: json['booking_id'] ?? '',
        deliveryPartnerId: json['delivery_partner_id'],
        status: json['status'] ?? 'assigned',
        pickedUpAt: json['picked_up_at'] != null
            ? DateTime.parse(json['picked_up_at'])
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'])
            : null,
        notes: json['notes'],
        assignedAt:
            DateTime.tryParse(json['assigned_at'] ?? '') ?? DateTime.now(),
      );
}

// Cart item used by MandiCartProvider
class MandiCartItem {
  final MandiProduct product;
  double quantity;
  double ratePerUnit;
  DateTime deliveryDate;

  MandiCartItem({
    required this.product,
    required this.quantity,
    required this.ratePerUnit,
    required this.deliveryDate,
  });

  double get subtotal => quantity * ratePerUnit;
}
