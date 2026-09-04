class HostelRoom {
  final String id;
  final String roomNumber;
  final String? wing;
  final String? buildingName;
  final int? floor;
  final int capacity;
  final int availableBeds;
  final double basePrice;
  final String? roomType;
  final List<String> amenities;
  final String? imageUrl;
  final String? description;
  final bool isActive;

  HostelRoom({
    required this.id,
    required this.roomNumber,
    this.wing,
    this.buildingName,
    this.floor,
    required this.capacity,
    required this.availableBeds,
    required this.basePrice,
    this.roomType,
    this.amenities = const [],
    this.imageUrl,
    this.description,
    this.isActive = true,
  });

  factory HostelRoom.fromJson(Map<String, dynamic> json) {
    return HostelRoom(
      id: json['id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '?',
      wing: json['wing'],
      buildingName: json['building_name'],
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      capacity: json['capacity'] ?? 1,
      availableBeds: json['available_beds'] ?? 1,
      basePrice: (json['base_price'] as num? ?? 6500.0).toDouble(),
      roomType: json['room_type']?.toString() ?? 'Standard',
      amenities: List<String>.from(json['amenities'] ?? []),
      imageUrl: (json['image_url'] != null && json['image_url'].toString().trim().isNotEmpty)
          ? json['image_url'].toString()
          : ((json['images'] is List && (json['images'] as List).isNotEmpty)
              ? (json['images'] as List).first.toString()
              : 'https://images.unsplash.com/photo-1555854817-5b273417735e'),
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class HostelEnrollment {
  final String id;
  final String studentId;
  final String roomId;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final double totalPrice;
  final String paymentStatus;
  final String status;

  HostelEnrollment({
    required this.id,
    required this.studentId,
    required this.roomId,
    required this.checkInDate,
    this.checkOutDate,
    required this.totalPrice,
    required this.paymentStatus,
    required this.status,
  });

  factory HostelEnrollment.fromJson(Map<String, dynamic> json) {
    return HostelEnrollment(
      id: json['id'],
      studentId: json['user_id'],
      roomId: json['room_id'],
      checkInDate: DateTime.parse(json['check_in_date']),
      checkOutDate: json['check_out_date'] != null ? DateTime.parse(json['check_out_date']) : null,
      totalPrice: (json['total_price'] as num).toDouble(),
      paymentStatus: json['payment_status'],
      status: json['status'],
    );
  }
}

class Complaint {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? category;
  final String status;
  final String priority;
  final String? imageUrl;
  final String? resolvedBy;
  final String? userName;
  final String? adminResponse;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.category,
    required this.status,
    required this.priority,
    this.imageUrl,
    this.resolvedBy,
    this.userName,
    this.adminResponse,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      status: json['status'],
      priority: json['priority'],
      imageUrl: json['image_url'],
      resolvedBy: json['resolved_by'],
      userName: (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) ? (json['profiles'] as List)[0]['full_name'] : (json['profiles'] is Map ? json['profiles']['full_name'] : null),
      adminResponse: json['admin_response'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
