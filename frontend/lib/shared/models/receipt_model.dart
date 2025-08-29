import 'package:json_annotation/json_annotation.dart';

part 'receipt_model.g.dart';

@JsonSerializable()
class Receipt {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @JsonKey(name: 'merchant_name')
  final String merchantName;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  final String category;
  @JsonKey(name: 'ocr_data')
  final Map<String, dynamic>? ocrData;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Receipt({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.merchantName,
    required this.totalAmount,
    required this.category,
    this.ocrData,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptToJson(this);

  Receipt copyWith({
    String? id,
    String? userId,
    String? imageUrl,
    String? merchantName,
    double? totalAmount,
    String? category,
    Map<String, dynamic>? ocrData,
    DateTime? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      category: category ?? this.category,
      ocrData: ocrData ?? this.ocrData,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Receipt(id: $id, merchantName: $merchantName, totalAmount: $totalAmount, category: $category)';
  }
}

@JsonSerializable()
class ReceiptCreate {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @JsonKey(name: 'merchant_name')
  final String merchantName;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  final String category;
  @JsonKey(name: 'ocr_data')
  final Map<String, dynamic>? ocrData;

  const ReceiptCreate({
    required this.userId,
    required this.imageUrl,
    required this.merchantName,
    required this.totalAmount,
    required this.category,
    this.ocrData,
  });

  factory ReceiptCreate.fromJson(Map<String, dynamic> json) => _$ReceiptCreateFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptCreateToJson(this);
}