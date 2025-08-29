import 'package:json_annotation/json_annotation.dart';

part 'receipt_ocr_data.g.dart';

@JsonSerializable()
class ReceiptOCRData {
  @JsonKey(name: 'raw_text')
  final String rawText;
  @JsonKey(name: 'merchant_name')
  final String merchantName;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  final DateTime date;
  final List<ReceiptItem> items;
  final String category;
  final double confidence;
  @JsonKey(name: 'processing_metadata')
  final Map<String, dynamic> processingMetadata;

  const ReceiptOCRData({
    required this.rawText,
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.items,
    required this.category,
    required this.confidence,
    required this.processingMetadata,
  });

  factory ReceiptOCRData.fromJson(Map<String, dynamic> json) =>
      _$ReceiptOCRDataFromJson(json);

  Map<String, dynamic> toJson() => _$ReceiptOCRDataToJson(this);

  ReceiptOCRData copyWith({
    String? rawText,
    String? merchantName,
    double? totalAmount,
    DateTime? date,
    List<ReceiptItem>? items,
    String? category,
    double? confidence,
    Map<String, dynamic>? processingMetadata,
  }) {
    return ReceiptOCRData(
      rawText: rawText ?? this.rawText,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      items: items ?? this.items,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      processingMetadata: processingMetadata ?? this.processingMetadata,
    );
  }

  @override
  String toString() {
    return 'ReceiptOCRData(merchantName: $merchantName, totalAmount: $totalAmount, confidence: $confidence)';
  }
}

@JsonSerializable()
class ReceiptItem {
  final String name;
  final double price;
  final int quantity;
  final String? category;

  const ReceiptItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.category,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);

  Map<String, dynamic> toJson() => _$ReceiptItemToJson(this);

  double get totalPrice => price * quantity;

  ReceiptItem copyWith({
    String? name,
    double? price,
    int? quantity,
    String? category,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptItem &&
        other.name == name &&
        other.price == price &&
        other.quantity == quantity &&
        other.category == category;
  }

  @override
  int get hashCode {
    return Object.hash(name, price, quantity, category);
  }

  @override
  String toString() {
    return 'ReceiptItem(name: $name, price: $price, quantity: $quantity)';
  }
}