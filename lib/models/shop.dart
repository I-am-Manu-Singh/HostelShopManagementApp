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
  
  // Mandi extensions
  final String unit; // e.g. kg, piece, dozen
  final String? rateDate;
  final bool isMandi;

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
    this.shelfLife,
    this.tags,
    this.ingredients,
    this.nutritionalInfo,
    this.howToUse,
    this.brand,
    this.weightMl,
    this.packageType,
    this.isBestseller = false,
    this.rating = 4.5,
    this.totalReviews = 0,
    this.unit = 'pcs',
    this.rateDate,
    this.isMandi = false,
  });

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

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Item',
      skuQr: json['sku_qr'],
      category: json['category'] ?? 'General',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0, 
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      stockQuantity: json['stock_quantity'] ?? 0,
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
      brand: json['brand'],
      weightMl: json['weight_ml'],
      packageType: json['package_type'],
      isBestseller: json['is_bestseller'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      totalReviews: json['total_reviews'] ?? 0,
      shelfLife: json['shelf_life'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      ingredients: json['ingredients'],
      nutritionalInfo: json['nutritional_info'],
      howToUse: json['how_to_use'],
      unit: json['unit'] ?? 'pcs',
      rateDate: json['rate_date'],
      isMandi: json['is_mandi'] ?? false,
    );
  }

  factory ShopItem.fromMap(Map<String, dynamic> map) => ShopItem.fromJson(map);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku_qr': skuQr,
      'category': category,
      'description': description,
      'price': price,
      'discount_price': discountPrice,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'is_available': isAvailable,
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
      'unit': unit,
      'rate_date': rateDate,
      'is_mandi': isMandi,
    };
  }
}

class ShopOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalPrice;
  final String paymentStatus;
  final String orderStatus;
  final DateTime createdAt;

  // Mandi extensions
  final bool isBooking;
  final DateTime? bookingDate;
  final double advancePaid;
  final String userType; // domestic, commercial
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
      userId: json['user_id']?.toString() ?? '',
      items: (json['items'] as List?)?.map((e) => OrderItem.fromJson(e)).toList() ?? [],
      totalPrice: (json['total_price'] as num? ?? 0.0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'Pending',
      orderStatus: json['order_status'] ?? 'Placed',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isBooking: json['is_booking'] ?? false,
      bookingDate: json['booking_date'] != null ? DateTime.tryParse(json['booking_date']) : null,
      advancePaid: (json['advance_paid'] as num?)?.toDouble() ?? 0.0,
      userType: json['user_type'] ?? 'domestic',
      deliveryAddress: json['delivery_address'],
      deliveryLocation: json['delivery_location'],
      deliveryPartnerId: json['delivery_partner_id'],
    );
  }
}

class OrderItem {
  final String id;
  final String name;
  final int qty;
  final double price;
  final double? weightQty;
  final String? weightUnit;

  OrderItem({required this.id, required this.name, required this.qty, required this.price, this.weightQty, this.weightUnit});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      name: json['name'],
      qty: json['qty'],
      price: (json['price'] as num).toDouble(),
      weightQty: json['weight_qty'] != null ? (json['weight_qty'] as num).toDouble() : null,
      weightUnit: json['weight_unit']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'qty': qty,
    'price': price,
    'weight_qty': weightQty,
    'weight_unit': weightUnit,
  };
}

class Attendance {
  final String id;
  final String userId;
  final String type; // 'hostel' or 'mess'
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

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user_id'],
      type: json['attendance_type'],
      status: json['status'],
      date: DateTime.parse(json['date']),
      mealType: json['meal_type'],
      markedBy: json['marked_by'],
    );
  }
}
