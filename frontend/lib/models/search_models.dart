// Search Models for Hey-Bills Flutter App
// Data models for semantic search functionality

import 'package:json_annotation/json_annotation.dart';

part 'search_models.g.dart';

@JsonSerializable()
class SearchResult {
  final String query;
  final IntentClassification intent;
  final Map<String, dynamic> entities;
  final SearchResultData results;
  final String timestamp;
  final bool fromCache;
  final String? correctedQuery;
  final String? originalQuery;

  const SearchResult({
    required this.query,
    required this.intent,
    required this.entities,
    required this.results,
    required this.timestamp,
    this.fromCache = false,
    this.correctedQuery,
    this.originalQuery,
  });

  bool get isEmpty => results.isEmpty;
  bool get hasResults => !isEmpty;
  bool get wasCorrected => correctedQuery != null && correctedQuery != originalQuery;

  SearchResult copyWith({
    String? query,
    IntentClassification? intent,
    Map<String, dynamic>? entities,
    SearchResultData? results,
    String? timestamp,
    bool? fromCache,
    String? correctedQuery,
    String? originalQuery,
  }) {
    return SearchResult(
      query: query ?? this.query,
      intent: intent ?? this.intent,
      entities: entities ?? this.entities,
      results: results ?? this.results,
      timestamp: timestamp ?? this.timestamp,
      fromCache: fromCache ?? this.fromCache,
      correctedQuery: correctedQuery ?? this.correctedQuery,
      originalQuery: originalQuery ?? this.originalQuery,
    );
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) => _$SearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$SearchResultToJson(this);
}

@JsonSerializable()
class SearchResultData {
  final String type;
  final int count;
  final List<SearchResultItem> items;

  const SearchResultData({
    required this.type,
    required this.count,
    required this.items,
  });

  bool get isEmpty => count == 0 || items.isEmpty;

  factory SearchResultData.fromJson(Map<String, dynamic> json) => _$SearchResultDataFromJson(json);
  Map<String, dynamic> toJson() => _$SearchResultDataToJson(this);
}

@JsonSerializable()
class SearchResultItem {
  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final double relevanceScore;
  final Map<String, dynamic> data;
  final String? snippet;

  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.relevanceScore,
    required this.data,
    this.snippet,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) => _$SearchResultItemFromJson(json);
  Map<String, dynamic> toJson() => _$SearchResultItemToJson(this);
}

@JsonSerializable()
class ReceiptSearchResult {
  final String query;
  final Map<String, dynamic> filters;
  final ReceiptResults results;
  final SearchMetadata metadata;
  final bool fromCache;

  const ReceiptSearchResult({
    required this.query,
    required this.filters,
    required this.results,
    required this.metadata,
    this.fromCache = false,
  });

  ReceiptSearchResult copyWith({
    String? query,
    Map<String, dynamic>? filters,
    ReceiptResults? results,
    SearchMetadata? metadata,
    bool? fromCache,
  }) {
    return ReceiptSearchResult(
      query: query ?? this.query,
      filters: filters ?? this.filters,
      results: results ?? this.results,
      metadata: metadata ?? this.metadata,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  factory ReceiptSearchResult.fromJson(Map<String, dynamic> json) => _$ReceiptSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptSearchResultToJson(this);
}

@JsonSerializable()
class ReceiptResults {
  final String type;
  final int count;
  final List<ReceiptSearchItem> items;

  const ReceiptResults({
    required this.type,
    required this.count,
    required this.items,
  });

  bool get isEmpty => count == 0 || items.isEmpty;

  factory ReceiptResults.fromJson(Map<String, dynamic> json) => _$ReceiptResultsFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptResultsToJson(this);
}

@JsonSerializable()
class ReceiptSearchItem {
  final String id;
  final String merchantName;
  final double totalAmount;
  final String purchaseDate;
  final String? categoryName;
  final double similarityScore;
  final double? confidenceScore;
  final List<String>? tags;
  final bool isBusinessExpense;
  final String? snippet;

  const ReceiptSearchItem({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.purchaseDate,
    this.categoryName,
    required this.similarityScore,
    this.confidenceScore,
    this.tags,
    required this.isBusinessExpense,
    this.snippet,
  });

  String get formattedAmount => '\$${totalAmount.toStringAsFixed(2)}';
  String get displayTitle => merchantName;
  String get displaySubtitle => '$formattedAmount on $purchaseDate';

  factory ReceiptSearchItem.fromJson(Map<String, dynamic> json) => _$ReceiptSearchItemFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptSearchItemToJson(this);
}

@JsonSerializable()
class WarrantySearchResult {
  final String query;
  final Map<String, dynamic> filters;
  final WarrantyResults results;
  final SearchMetadata metadata;

  const WarrantySearchResult({
    required this.query,
    required this.filters,
    required this.results,
    required this.metadata,
  });

  factory WarrantySearchResult.fromJson(Map<String, dynamic> json) => _$WarrantySearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantySearchResultToJson(this);
}

@JsonSerializable()
class WarrantyResults {
  final String type;
  final int count;
  final List<WarrantySearchItem> items;

  const WarrantyResults({
    required this.type,
    required this.count,
    required this.items,
  });

  bool get isEmpty => count == 0 || items.isEmpty;

  factory WarrantyResults.fromJson(Map<String, dynamic> json) => _$WarrantyResultsFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyResultsToJson(this);
}

@JsonSerializable()
class WarrantySearchItem {
  final String id;
  final String productName;
  final String? productBrand;
  final String? productModel;
  final String warrantyEndDate;
  final String warrantyStatus;
  final double similarityScore;
  final int? daysUntilExpiry;
  final String? supportContact;

  const WarrantySearchItem({
    required this.id,
    required this.productName,
    this.productBrand,
    this.productModel,
    required this.warrantyEndDate,
    required this.warrantyStatus,
    required this.similarityScore,
    this.daysUntilExpiry,
    this.supportContact,
  });

  String get displayTitle => productName;
  String get displaySubtitle => 
      '${productBrand ?? ''} ${productModel ?? ''}'.trim();
  String get warrantyStatusDisplay => warrantyStatus.replaceAll('_', ' ').toUpperCase();
  
  bool get isExpiringSoon => daysUntilExpiry != null && daysUntilExpiry! < 30;
  bool get isExpired => warrantyStatus == 'expired';

  factory WarrantySearchItem.fromJson(Map<String, dynamic> json) => _$WarrantySearchItemFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantySearchItemToJson(this);
}

@JsonSerializable()
class HybridSearchResult {
  final String query;
  final Map<String, double> weights;
  final Map<String, dynamic> filters;
  final HybridResults results;
  final SearchMetadata metadata;

  const HybridSearchResult({
    required this.query,
    required this.weights,
    required this.filters,
    required this.results,
    required this.metadata,
  });

  factory HybridSearchResult.fromJson(Map<String, dynamic> json) => _$HybridSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$HybridSearchResultToJson(this);
}

@JsonSerializable()
class HybridResults {
  final String type;
  final int count;
  final List<HybridSearchItem> items;

  const HybridResults({
    required this.type,
    required this.count,
    required this.items,
  });

  bool get isEmpty => count == 0 || items.isEmpty;

  factory HybridResults.fromJson(Map<String, dynamic> json) => _$HybridResultsFromJson(json);
  Map<String, dynamic> toJson() => _$HybridResultsToJson(this);
}

@JsonSerializable()
class HybridSearchItem {
  final String id;
  final String merchantName;
  final double totalAmount;
  final String purchaseDate;
  final String? categoryName;
  final double combinedScore;
  final double vectorScore;
  final double textScore;
  final String? snippet;
  final String rankExplanation;

  const HybridSearchItem({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.purchaseDate,
    this.categoryName,
    required this.combinedScore,
    required this.vectorScore,
    required this.textScore,
    this.snippet,
    required this.rankExplanation,
  });

  String get formattedAmount => '\$${totalAmount.toStringAsFixed(2)}';
  String get displayTitle => merchantName;
  String get displaySubtitle => '$formattedAmount on $purchaseDate';

  factory HybridSearchItem.fromJson(Map<String, dynamic> json) => _$HybridSearchItemFromJson(json);
  Map<String, dynamic> toJson() => _$HybridSearchItemToJson(this);
}

@JsonSerializable()
class SpendingAnalysis {
  final String query;
  final String timeframe;
  final List<String> insightTypes;
  final SpendingAnalysisData analysis;
  final SearchMetadata metadata;

  const SpendingAnalysis({
    required this.query,
    required this.timeframe,
    required this.insightTypes,
    required this.analysis,
    required this.metadata,
  });

  factory SpendingAnalysis.fromJson(Map<String, dynamic> json) => _$SpendingAnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$SpendingAnalysisToJson(this);
}

@JsonSerializable()
class SpendingAnalysisData {
  final String type;
  final String timeframe;
  final List<SpendingInsight> insights;

  const SpendingAnalysisData({
    required this.type,
    required this.timeframe,
    required this.insights,
  });

  factory SpendingAnalysisData.fromJson(Map<String, dynamic> json) => _$SpendingAnalysisDataFromJson(json);
  Map<String, dynamic> toJson() => _$SpendingAnalysisDataToJson(this);
}

@JsonSerializable()
class SpendingInsight {
  final String type;
  final String title;
  final String description;
  final double confidence;
  final Map<String, dynamic>? data;
  final List<String> recommendations;

  const SpendingInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    this.data,
    required this.recommendations,
  });

  String get confidenceDisplay => '${(confidence * 100).round()}%';
  bool get isHighConfidence => confidence > 0.8;

  factory SpendingInsight.fromJson(Map<String, dynamic> json) => _$SpendingInsightFromJson(json);
  Map<String, dynamic> toJson() => _$SpendingInsightToJson(this);
}

@JsonSerializable()
class IntentClassification {
  final String primary;
  final List<String> secondary;
  final double confidence;
  final Map<String, double> scores;

  const IntentClassification({
    required this.primary,
    required this.secondary,
    required this.confidence,
    required this.scores,
  });

  String get primaryDisplay => primary.replaceAll('_', ' ').toUpperCase();
  bool get isConfident => confidence > 0.7;

  factory IntentClassification.fromJson(Map<String, dynamic> json) => _$IntentClassificationFromJson(json);
  Map<String, dynamic> toJson() => _$IntentClassificationToJson(this);
}

@JsonSerializable()
class SearchSuggestion {
  final String text;
  final String type;
  final double confidence;

  const SearchSuggestion({
    required this.text,
    required this.type,
    required this.confidence,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) => _$SearchSuggestionFromJson(json);
  Map<String, dynamic> toJson() => _$SearchSuggestionToJson(this);
}

@JsonSerializable()
class DuplicateDetectionResult {
  final String receiptId;
  final double threshold;
  final DuplicateResults results;
  final SearchMetadata metadata;

  const DuplicateDetectionResult({
    required this.receiptId,
    required this.threshold,
    required this.results,
    required this.metadata,
  });

  factory DuplicateDetectionResult.fromJson(Map<String, dynamic> json) => _$DuplicateDetectionResultFromJson(json);
  Map<String, dynamic> toJson() => _$DuplicateDetectionResultToJson(this);
}

@JsonSerializable()
class DuplicateResults {
  final String type;
  final List<DuplicateGroup> groups;

  const DuplicateResults({
    required this.type,
    required this.groups,
  });

  bool get hasDuplicates => groups.isNotEmpty;
  int get duplicateCount => groups.fold(0, (sum, group) => sum + group.receipts.length);

  factory DuplicateResults.fromJson(Map<String, dynamic> json) => _$DuplicateResultsFromJson(json);
  Map<String, dynamic> toJson() => _$DuplicateResultsToJson(this);
}

@JsonSerializable()
class DuplicateGroup {
  final String confidence;
  final List<ReceiptSearchItem> receipts;
  final String reason;

  const DuplicateGroup({
    required this.confidence,
    required this.receipts,
    required this.reason,
  });

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) => _$DuplicateGroupFromJson(json);
  Map<String, dynamic> toJson() => _$DuplicateGroupToJson(this);
}

@JsonSerializable()
class SearchMetadata {
  final String searchType;
  final String timestamp;
  final Map<String, dynamic>? additionalData;

  const SearchMetadata({
    required this.searchType,
    required this.timestamp,
    this.additionalData,
  });

  factory SearchMetadata.fromJson(Map<String, dynamic> json) => _$SearchMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$SearchMetadataToJson(this);
}

@JsonSerializable()
class SearchOptions {
  final double? threshold;
  final int? limit;
  final String? metric;
  final bool? includeExpired;
  final bool? realTimeUpdates;
  final Map<String, dynamic>? customOptions;

  const SearchOptions({
    this.threshold,
    this.limit,
    this.metric,
    this.includeExpired,
    this.realTimeUpdates,
    this.customOptions,
  });

  factory SearchOptions.fromJson(Map<String, dynamic> json) => _$SearchOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$SearchOptionsToJson(this);
}

@JsonSerializable()
class ReceiptFilters {
  final String? merchant;
  final String? category;
  final DateRange? dateRange;
  final AmountRange? amountRange;
  final List<String>? tags;
  final bool? businessExpensesOnly;

  const ReceiptFilters({
    this.merchant,
    this.category,
    this.dateRange,
    this.amountRange,
    this.tags,
    this.businessExpensesOnly,
  });

  bool get hasFilters => 
      merchant != null || 
      category != null || 
      dateRange != null || 
      amountRange != null || 
      (tags != null && tags!.isNotEmpty) ||
      businessExpensesOnly == true;

  @override
  int get hashCode => Object.hash(
    merchant, 
    category, 
    dateRange, 
    amountRange, 
    tags, 
    businessExpensesOnly
  );

  factory ReceiptFilters.fromJson(Map<String, dynamic> json) => _$ReceiptFiltersFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptFiltersToJson(this);
}

@JsonSerializable()
class WarrantyFilters {
  final String? brand;
  final String? status;
  final bool? expiringSoon;
  final DateRange? purchaseDateRange;

  const WarrantyFilters({
    this.brand,
    this.status,
    this.expiringSoon,
    this.purchaseDateRange,
  });

  bool get hasFilters => 
      brand != null || 
      status != null || 
      expiringSoon != null ||
      purchaseDateRange != null;

  factory WarrantyFilters.fromJson(Map<String, dynamic> json) => _$WarrantyFiltersFromJson(json);
  Map<String, dynamic> toJson() => _$WarrantyFiltersToJson(this);
}

@JsonSerializable()
class DateRange {
  final String start;
  final String end;

  const DateRange({
    required this.start,
    required this.end,
  });

  DateTime get startDate => DateTime.parse(start);
  DateTime get endDate => DateTime.parse(end);
  Duration get duration => endDate.difference(startDate);

  factory DateRange.fromJson(Map<String, dynamic> json) => _$DateRangeFromJson(json);
  Map<String, dynamic> toJson() => _$DateRangeToJson(this);
}

@JsonSerializable()
class AmountRange {
  final double min;
  final double max;

  const AmountRange({
    required this.min,
    required this.max,
  });

  String get displayRange => '\$${min.toStringAsFixed(2)} - \$${max.toStringAsFixed(2)}';
  bool contains(double amount) => amount >= min && amount <= max;

  factory AmountRange.fromJson(Map<String, dynamic> json) => _$AmountRangeFromJson(json);
  Map<String, dynamic> toJson() => _$AmountRangeToJson(this);
}