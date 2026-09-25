class ShopItem {
  final String id;
  final String name;
  final String? skuQr;
  final String category;
  final String? description;
  final double price;
  final double? discountPrice;
  final int stockQuantity;
  final String? imageUrl;
  final bool isAvailable;

  // Food / Diet
  final bool isNonVeg;

  // Mandi
  final String unit;
  final String? rateDate;
  final bool isMandi;

  // POS & Tax
  final String? barcode;
  final String? hsnCode;
  final double taxRate;
  final double? costPrice;
  final bool isTaxInclusive;
  final int minStockAlert;

  // Product information
  final String? brand;
  final String? weightMl;
  final String? packageType;
  final bool isBestseller;
  final double rating;
  final int totalReviews;
  final String? shelfLife;
  final List<String>? tags;
  final String? ingredients;
  final Map<String, dynamic>? nutritionalInfo;
  final String? howToUse;

  ShopItem({
    required this.id,
    required this.name,
    this.skuQr,
    required this.category,
    this.description,
    required this.price,
    this.discountPrice,
    required this.stockQuantity,
    this.imageUrl,
    this.isAvailable = true,

    // Food
    this.isNonVeg = false,

    // Product information
    this.brand,
    this.weightMl,
    this.packageType,
    this.isBestseller = false,
    this.rating = 4.5,
    this.totalReviews = 0,
    this.shelfLife,
    this.tags,
    this.ingredients,
    this.nutritionalInfo,
    this.howToUse,

    // Mandi
    this.unit = 'pcs',
    this.rateDate,
    this.isMandi = false,

    // POS & Tax
    this.barcode,
    this.hsnCode,
    this.taxRate = 0.0,
    this.costPrice,
    this.isTaxInclusive = true,
    this.minStockAlert = 5,
  });

  // ---------------------------------------------------------------------------
  // JSON → MODEL
  // ---------------------------------------------------------------------------

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',

      skuQr: json['sku_qr']?.toString(),

      category: json['category']?.toString() ?? 'General',

      description: json['description']?.toString(),

      price: (json['price'] as num?)?.toDouble() ?? 0.0,

      discountPrice:
          (json['discount_price'] as num?)?.toDouble(),

      stockQuantity:
          (json['stock_quantity'] as num?)?.toInt() ?? 0,

      imageUrl: json['image_url']?.toString(),

      isAvailable:
          json['is_available'] as bool? ?? true,

      // -------------------------------------------------
      // FOOD
      // -------------------------------------------------

      isNonVeg:
          json['is_non_veg'] as bool? ?? false,

      // -------------------------------------------------
      // PRODUCT INFO
      // -------------------------------------------------

      brand: json['brand']?.toString(),

      weightMl:
          json['weight_ml']?.toString(),

      packageType:
          json['package_type']?.toString(),

      isBestseller:
          json['is_bestseller'] as bool? ?? false,

      rating:
          (json['rating'] as num?)?.toDouble() ?? 4.5,

      totalReviews:
          (json['total_reviews'] as num?)?.toInt() ?? 0,

      shelfLife:
          json['shelf_life']?.toString(),

      tags: json['tags'] != null
          ? List<String>.from(
              (json['tags'] as List).map(
                (e) => e.toString(),
              ),
            )
          : null,

      ingredients:
          json['ingredients']?.toString(),

      nutritionalInfo:
          json['nutritional_info'] != null
              ? Map<String, dynamic>.from(
                  json['nutritional_info'] as Map,
                )
              : null,

      howToUse:
          json['how_to_use']?.toString(),

      // -------------------------------------------------
      // MANDI
      // -------------------------------------------------

      unit:
          json['unit']?.toString() ?? 'pcs',

      rateDate:
          json['rate_date']?.toString(),

      isMandi:
          json['is_mandi'] as bool? ?? false,

      // -------------------------------------------------
      // POS & TAX
      // -------------------------------------------------

      barcode:
          json['barcode']?.toString() ??
          json['sku_qr']?.toString(),

      hsnCode:
          json['hsn_code']?.toString(),

      taxRate:
          (json['tax_rate'] as num?)?.toDouble() ?? 0.0,

      costPrice:
          (json['cost_price'] as num?)?.toDouble(),

      isTaxInclusive:
          json['is_tax_inclusive'] as bool? ?? true,

      minStockAlert:
          (json['min_stock_alert'] as num?)?.toInt() ?? 5,
    );
  }

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    return ShopItem.fromJson(map);
  }

  // ---------------------------------------------------------------------------
  // MODEL → MAP
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku_qr': skuQr,
      'category': category,
      'description': description,

      'price': price,
      'discount_price': discountPrice,
      'stock_quantity': stockQuantity,

      'image_url': imageUrl,
      'is_available': isAvailable,

      // Food
      'is_non_veg': isNonVeg,

      // Product information
      'brand': brand,
      'weight_ml': weightMl,
      'package_type': packageType,
      'is_bestseller': isBestseller,
      'rating': rating,
      'total_reviews': totalReviews,
      'shelf_life': shelfLife,
      'tags': tags,
      'ingredients': ingredients,
      'nutritional_info': nutritionalInfo,
      'how_to_use': howToUse,

      // Mandi
      'unit': unit,
      'rate_date': rateDate,
      'is_mandi': isMandi,

      // POS & Tax
      'barcode': barcode,
      'hsn_code': hsnCode,
      'tax_rate': taxRate,
      'cost_price': costPrice,
      'is_tax_inclusive': isTaxInclusive,
      'min_stock_alert': minStockAlert,
    };
  }
}

// ============================================================================
// SHOP ORDER
// ============================================================================

class ShopOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalPrice;
  final String paymentStatus;
  final String orderStatus;
  final DateTime createdAt;

  // Mandi / Booking
  final bool isBooking;
  final DateTime? bookingDate;
  final double advancePaid;
  final String userType;
  final String? deliveryAddress;
  final String? deliveryLocation;
  final String? deliveryPartnerId;

  ShopOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.paymentStatus,
    required this.orderStatus,
    required this.createdAt,
    this.isBooking = false,
    this.bookingDate,
    this.advancePaid = 0.0,
    this.userType = 'domestic',
    this.deliveryAddress,
    this.deliveryLocation,
    this.deliveryPartnerId,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    return ShopOrder(
      id: json['id']?.toString() ?? '',

      userId:
          json['user_id']?.toString() ?? '',

      items: (json['items'] as List?)
              ?.map(
                (e) => OrderItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],

      totalPrice:
          (json['total_price'] as num?)?.toDouble() ?? 0.0,

      paymentStatus:
          json['payment_status']?.toString() ?? 'Pending',

      orderStatus:
          json['order_status']?.toString() ?? 'Placed',

      createdAt:
          DateTime.tryParse(
                json['created_at']?.toString() ?? '',
              ) ??
              DateTime.now(),

      isBooking:
          json['is_booking'] as bool? ?? false,

      bookingDate:
          json['booking_date'] != null
              ? DateTime.tryParse(
                  json['booking_date'].toString(),
                )
              : null,

      advancePaid:
          (json['advance_paid'] as num?)?.toDouble() ?? 0.0,

      userType:
          json['user_type']?.toString() ?? 'domestic',

      deliveryAddress:
          json['delivery_address']?.toString(),

      deliveryLocation:
          json['delivery_location']?.toString(),

      deliveryPartnerId:
          json['delivery_partner_id']?.toString(),
    );
  }
}

// ============================================================================
// ORDER ITEM
// ============================================================================

class OrderItem {
  final String id;
  final String name;
  final int qty;
  final double price;
  final double? weightQty;
  final String? weightUnit;
  final double taxRate;
  final String? hsnCode;

  OrderItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    this.weightQty,
    this.weightUnit,
    this.taxRate = 0.0,
    this.hsnCode,
  });

  factory OrderItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrderItem(
      id: json['id']?.toString() ?? '',

      name:
          json['name']?.toString() ?? '',

      qty:
          (json['qty'] as num?)?.toInt() ?? 0,

      price:
          (json['price'] as num?)?.toDouble() ?? 0.0,

      weightQty:
          json['weight_qty'] != null
              ? (json['weight_qty'] as num?)?.toDouble()
              : null,

      weightUnit:
          json['weight_unit']?.toString(),

      taxRate:
          (json['tax_rate'] as num?)?.toDouble() ?? 0.0,

      hsnCode:
          json['hsn_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'price': price,
      'weight_qty': weightQty,
      'weight_unit': weightUnit,
      'tax_rate': taxRate,
      'hsn_code': hsnCode,
    };
  }
}

// ============================================================================
// ATTENDANCE
// ============================================================================

class Attendance {
  final String id;
  final String userId;
  final String type;
  final String status;
  final DateTime date;
  final String? mealType;
  final String? markedBy;

  Attendance({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.date,
    this.mealType,
    this.markedBy,
  });

  factory Attendance.fromJson(
    Map<String, dynamic> json,
  ) {
    return Attendance(
      id:
          json['id']?.toString() ?? '',

      userId:
          json['user_id']?.toString() ?? '',

      type:
          json['attendance_type']?.toString() ?? 'hostel',

      status:
          json['status']?.toString() ?? '',

      date:
          DateTime.tryParse(
                json['date']?.toString() ?? '',
              ) ??
              DateTime.now(),

      mealType:
          json['meal_type']?.toString(),

      markedBy:
          json['marked_by']?.toString(),
    );
  }
}