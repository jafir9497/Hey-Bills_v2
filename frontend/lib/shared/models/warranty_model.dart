import 'package:json_annotation/json_annotation.dart';

part 'warranty_model.g.dart';

@JsonSerializable()
class Warranty {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'product_name')
  final String productName;
  @JsonKey(name: 'warranty_end_date')
  final DateTime warrantyEndDate;
  @JsonKey(name: 'alert_preferences')
  final WarrantyAlertPreferences? alertPreferences;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Warranty({
    required this.id,
    required this.userId,
    required this.productName,
    required this.warrantyEndDate,
    this.alertPreferences,
    required this.createdAt,
  });

  factory Warranty.fromJson(Map<String, dynamic> json) => _$WarrantyFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyToJson(this);

  /// Check if warranty is expiring within the given number of days
  bool isExpiringWithin(int days) {
    final now = DateTime.now();
    final daysUntilExpiry = warrantyEndDate.difference(now).inDays;
    return daysUntilExpiry <= days && daysUntilExpiry >= 0;
  }

  /// Check if warranty has already expired
  bool get isExpired {
    return warrantyEndDate.isBefore(DateTime.now());
  }

  /// Get days until warranty expiry (negative if expired)
  int get daysUntilExpiry {
    final now = DateTime.now();
    return warrantyEndDate.difference(now).inDays;
  }

  /// Get warranty status
  WarrantyStatus get status {
    if (isExpired) return WarrantyStatus.expired;
    if (isExpiringWithin(30)) return WarrantyStatus.expiringSoon;
    return WarrantyStatus.active;
  }

  Warranty copyWith({
    String? id,
    String? userId,
    String? productName,
    DateTime? warrantyEndDate,
    WarrantyAlertPreferences? alertPreferences,
    DateTime? createdAt,
  }) {
    return Warranty(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      alertPreferences: alertPreferences ?? this.alertPreferences,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Warranty && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Warranty(id: $id, productName: $productName, warrantyEndDate: $warrantyEndDate, status: $status)';
  }
}

@JsonSerializable()
class WarrantyAlertPreferences {
  @JsonKey(name: 'alert_days')
  final List<int> alertDays;
  @JsonKey(name: 'email_enabled')
  final bool emailEnabled;
  @JsonKey(name: 'push_enabled')
  final bool pushEnabled;

  const WarrantyAlertPreferences({
    required this.alertDays,
    required this.emailEnabled,
    required this.pushEnabled,
  });

  factory WarrantyAlertPreferences.fromJson(Map<String, dynamic> json) => 
      _$WarrantyAlertPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyAlertPreferencesToJson(this);

  WarrantyAlertPreferences copyWith({
    List<int>? alertDays,
    bool? emailEnabled,
    bool? pushEnabled,
  }) {
    return WarrantyAlertPreferences(
      alertDays: alertDays ?? this.alertDays,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}

@JsonSerializable()
class WarrantyCreate {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'product_name')
  final String productName;
  @JsonKey(name: 'warranty_end_date')
  final DateTime warrantyEndDate;
  @JsonKey(name: 'alert_preferences')
  final WarrantyAlertPreferences? alertPreferences;

  const WarrantyCreate({
    required this.userId,
    required this.productName,
    required this.warrantyEndDate,
    this.alertPreferences,
  });

  factory WarrantyCreate.fromJson(Map<String, dynamic> json) => _$WarrantyCreateFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyCreateToJson(this);
}

enum WarrantyStatus {
  @JsonValue('active')
  active,
  @JsonValue('expiring_soon')
  expiringSoon,
  @JsonValue('expired')
  expired,
}

extension WarrantyStatusExtension on WarrantyStatus {
  String get displayName {
    switch (this) {
      case WarrantyStatus.active:
        return 'Active';
      case WarrantyStatus.expiringSoon:
        return 'Expiring Soon';
      case WarrantyStatus.expired:
        return 'Expired';
    }
  }
}