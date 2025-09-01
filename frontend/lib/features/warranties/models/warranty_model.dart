import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'warranty_model.g.dart';

@JsonSerializable()
class Warranty extends Equatable {
  final String id;
  final String userId;
  final String productName;
  final String brand;
  final String model;
  final String serialNumber;
  final String category;
  final DateTime purchaseDate;
  final DateTime warrantyStartDate;
  final DateTime warrantyEndDate;
  final int warrantyPeriodMonths;
  final double purchasePrice;
  final String retailer;
  final String description;
  final WarrantyStatus status;
  final List<String> attachments;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Warranty({
    required this.id,
    required this.userId,
    required this.productName,
    required this.brand,
    this.model = '',
    this.serialNumber = '',
    required this.category,
    required this.purchaseDate,
    required this.warrantyStartDate,
    required this.warrantyEndDate,
    required this.warrantyPeriodMonths,
    this.purchasePrice = 0.0,
    this.retailer = '',
    this.description = '',
    required this.status,
    this.attachments = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Warranty.fromJson(Map<String, dynamic> json) => _$WarrantyFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyToJson(this);

  // Helper getters
  bool get isExpired => DateTime.now().isAfter(warrantyEndDate);
  bool get isExpiringSoon => 
      !isExpired && warrantyEndDate.difference(DateTime.now()).inDays <= 30;
  
  int get daysRemaining => isExpired 
      ? 0 
      : warrantyEndDate.difference(DateTime.now()).inDays;
  
  double get completionPercentage {
    final totalDays = warrantyEndDate.difference(warrantyStartDate).inDays;
    final elapsedDays = DateTime.now().difference(warrantyStartDate).inDays;
    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  Warranty copyWith({
    String? id,
    String? userId,
    String? productName,
    String? brand,
    String? model,
    String? serialNumber,
    String? category,
    DateTime? purchaseDate,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    int? warrantyPeriodMonths,
    double? purchasePrice,
    String? retailer,
    String? description,
    WarrantyStatus? status,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Warranty(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      warrantyPeriodMonths: warrantyPeriodMonths ?? this.warrantyPeriodMonths,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      retailer: retailer ?? this.retailer,
      description: description ?? this.description,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        productName,
        brand,
        model,
        serialNumber,
        category,
        purchaseDate,
        warrantyStartDate,
        warrantyEndDate,
        warrantyPeriodMonths,
        purchasePrice,
        retailer,
        description,
        status,
        attachments,
        metadata,
        createdAt,
        updatedAt,
      ];
}

enum WarrantyStatus {
  @JsonValue('active')
  active,
  @JsonValue('expired')
  expired,
  @JsonValue('claimed')
  claimed,
  @JsonValue('archived')
  archived,
}

@JsonSerializable()
class WarrantyNotification extends Equatable {
  final String id;
  final String warrantyId;
  final String userId;
  final WarrantyNotificationType type;
  final String title;
  final String message;
  final DateTime scheduledDate;
  final bool isRead;
  final DateTime createdAt;

  const WarrantyNotification({
    required this.id,
    required this.warrantyId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.scheduledDate,
    this.isRead = false,
    required this.createdAt,
  });

  factory WarrantyNotification.fromJson(Map<String, dynamic> json) =>
      _$WarrantyNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyNotificationToJson(this);

  WarrantyNotification copyWith({
    String? id,
    String? warrantyId,
    String? userId,
    WarrantyNotificationType? type,
    String? title,
    String? message,
    DateTime? scheduledDate,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return WarrantyNotification(
      id: id ?? this.id,
      warrantyId: warrantyId ?? this.warrantyId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        warrantyId,
        userId,
        type,
        title,
        message,
        scheduledDate,
        isRead,
        createdAt,
      ];
}

enum WarrantyNotificationType {
  @JsonValue('expiring_soon')
  expiringSoon,
  @JsonValue('expired')
  expired,
  @JsonValue('renewal_reminder')
  renewalReminder,
}

@JsonSerializable()
class WarrantyClaim extends Equatable {
  final String id;
  final String warrantyId;
  final String userId;
  final String issueDescription;
  final WarrantyClaimStatus status;
  final DateTime claimDate;
  final DateTime? resolvedDate;
  final String? resolution;
  final List<String> attachments;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WarrantyClaim({
    required this.id,
    required this.warrantyId,
    required this.userId,
    required this.issueDescription,
    required this.status,
    required this.claimDate,
    this.resolvedDate,
    this.resolution,
    this.attachments = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) =>
      _$WarrantyClaimFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyClaimToJson(this);

  WarrantyClaim copyWith({
    String? id,
    String? warrantyId,
    String? userId,
    String? issueDescription,
    WarrantyClaimStatus? status,
    DateTime? claimDate,
    DateTime? resolvedDate,
    String? resolution,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarrantyClaim(
      id: id ?? this.id,
      warrantyId: warrantyId ?? this.warrantyId,
      userId: userId ?? this.userId,
      issueDescription: issueDescription ?? this.issueDescription,
      status: status ?? this.status,
      claimDate: claimDate ?? this.claimDate,
      resolvedDate: resolvedDate ?? this.resolvedDate,
      resolution: resolution ?? this.resolution,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        warrantyId,
        userId,
        issueDescription,
        status,
        claimDate,
        resolvedDate,
        resolution,
        attachments,
        metadata,
        createdAt,
        updatedAt,
      ];
}

enum WarrantyClaimStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('resolved')
  resolved,
  @JsonValue('rejected')
  rejected,
}