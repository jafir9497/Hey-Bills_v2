// Semantic Search Service for Flutter Frontend
// Integrates with backend AI search APIs for enhanced receipt and warranty search

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../shared/utils/api_client.dart';
import '../../models/search_models.dart';

class SemanticSearchService {
  final ApiClient _apiClient;
  
  // Cache for recent searches
  final Map<String, SearchResult> _searchCache = {};
  final Duration _cacheTimeout = const Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  SemanticSearchService(this._apiClient);

  /// Main semantic search with intent classification
  Future<SearchResult> semanticSearch(String query, {SearchOptions? options}) async {
    try {
      // Check cache first
      final cachedResult = _getCachedSearch(query);
      if (cachedResult != null) {
        return cachedResult;
      }

      final requestBody = {
        'query': query,
        'options': options?.toJson() ?? {},
      };

      final response = await _apiClient.post('/search/semantic', requestBody);
      final result = SearchResult.fromJson(response.data);
      
      // Cache the result
      _cacheSearch(query, result);
      
      return result;
    } catch (e) {
      throw SearchException('Failed to perform semantic search: $e');
    }
  }

  /// Specialized receipt search
  Future<ReceiptSearchResult> searchReceipts(
    String query, {
    ReceiptFilters? filters,
    SearchOptions? options,
  }) async {
    try {
      final cachedResult = _getCachedReceiptSearch(query, filters);
      if (cachedResult != null) {
        return cachedResult;
      }

      final requestBody = {
        'query': query,
        'filters': filters?.toJson() ?? {},
        'options': options?.toJson() ?? {},
      };

      final response = await _apiClient.post('/search/receipts', requestBody);
      final result = ReceiptSearchResult.fromJson(response.data);
      
      _cacheReceiptSearch(query, filters, result);
      
      return result;
    } catch (e) {
      throw SearchException('Failed to search receipts: $e');
    }
  }

  /// Warranty search and recommendations
  Future<WarrantySearchResult> searchWarranties(
    String query, {
    WarrantyFilters? filters,
    SearchOptions? options,
  }) async {
    try {
      final requestBody = {
        'query': query,
        'filters': filters?.toJson() ?? {},
        'options': options?.toJson() ?? {},
      };

      final response = await _apiClient.post('/search/warranties', requestBody);
      return WarrantySearchResult.fromJson(response.data);
    } catch (e) {
      throw SearchException('Failed to search warranties: $e');
    }
  }

  /// Hybrid search combining vector and text search
  Future<HybridSearchResult> hybridSearch(
    String query, {
    double vectorWeight = 0.7,
    double textWeight = 0.3,
    Map<String, dynamic>? filters,
    SearchOptions? options,
  }) async {
    try {
      final requestBody = {
        'query': query,
        'vectorWeight': vectorWeight,
        'textWeight': textWeight,
        'filters': filters ?? {},
        'options': options?.toJson() ?? {},
      };

      final response = await _apiClient.post('/search/hybrid', requestBody);
      return HybridSearchResult.fromJson(response.data);
    } catch (e) {
      throw SearchException('Failed to perform hybrid search: $e');
    }
  }

  /// AI-powered spending analysis
  Future<SpendingAnalysis> analyzeSpending({
    String query = 'analyze my spending patterns',
    int timeframe = 90,
    List<String> insightTypes = const ['patterns', 'anomalies', 'trends'],
  }) async {
    try {
      final requestBody = {
        'query': query,
        'timeframe': timeframe,
        'insightTypes': insightTypes,
      };

      final response = await _apiClient.post('/search/analyze-spending', requestBody);
      return SpendingAnalysis.fromJson(response.data);
    } catch (e) {
      throw SearchException('Failed to analyze spending: $e');
    }
  }

  /// Find duplicate receipts
  Future<DuplicateDetectionResult> findDuplicates(String receiptId) async {
    try {
      final requestBody = {
        'receiptId': receiptId,
        'threshold': 0.85,
      };

      final response = await _apiClient.post('/search/find-duplicates', requestBody);
      return DuplicateDetectionResult.fromJson(response.data);
    } catch (e) {
      throw SearchException('Failed to find duplicates: $e');
    }
  }

  /// Classify query intent
  Future<IntentClassification> classifyIntent(String query) async {
    try {
      final requestBody = {'query': query};

      final response = await _apiClient.post('/search/classify-intent', requestBody);
      return IntentClassification.fromJson(response.data);
    } catch (e) {
      throw SearchException('Failed to classify intent: $e');
    }
  }

  /// Get search suggestions
  Future<List<SearchSuggestion>> getSuggestions({String query = '', int limit = 5}) async {
    try {
      final response = await _apiClient.get('/search/suggestions', queryParameters: {
        'query': query,
        'limit': limit.toString(),
      });

      return (response.data['suggestions'] as List)
          .map((json) => SearchSuggestion.fromJson(json))
          .toList();
    } catch (e) {
      throw SearchException('Failed to get search suggestions: $e');
    }
  }

  /// Stream search results for real-time updates
  Stream<SearchResult> searchStream(String query, {SearchOptions? options}) async* {
    // Initial search
    yield await semanticSearch(query, options: options);

    // Set up periodic updates if needed
    if (options?.realTimeUpdates ?? false) {
      final timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          // Force refresh from server
          _invalidateCache(query);
          final result = await semanticSearch(query, options: options);
          // Note: In a real stream implementation, this would use a StreamController
        } catch (e) {
          // Handle errors silently for background updates
        }
      });

      // Clean up timer after some time
      Timer(const Duration(minutes: 5), () => timer.cancel());
    }
  }

  /// Smart query enhancement
  Future<String> enhanceQuery(String originalQuery) async {
    try {
      // Local query enhancement before sending to server
      String enhanced = originalQuery.trim();

      // Add common synonyms and context
      final enhancements = {
        'restaurant': 'restaurant dining food meal',
        'gas': 'gas fuel gasoline petrol station',
        'grocery': 'grocery store food shopping market',
        'pharmacy': 'pharmacy drug store medicine health',
        'electronics': 'electronics technology computer phone',
      };

      final lowerQuery = enhanced.toLowerCase();
      for (final entry in enhancements.entries) {
        if (lowerQuery.contains(entry.key)) {
          enhanced += ' ${entry.value}';
          break; // Only add one enhancement to avoid query bloat
        }
      }

      return enhanced;
    } catch (e) {
      return originalQuery; // Fall back to original query
    }
  }

  /// Batch search for multiple queries
  Future<List<SearchResult>> batchSearch(List<String> queries, {SearchOptions? options}) async {
    try {
      final futures = queries.map((query) => semanticSearch(query, options: options));
      return await Future.wait(futures);
    } catch (e) {
      throw SearchException('Failed to perform batch search: $e');
    }
  }

  /// Search with autocorrection
  Future<SearchResult> searchWithAutocorrect(String query, {SearchOptions? options}) async {
    try {
      // First try the original query
      final result = await semanticSearch(query, options: options);
      
      // If no results and query seems to have typos, try corrections
      if (result.isEmpty && _hasLikelyTypos(query)) {
        final correctedQuery = _attemptSpellCorrection(query);
        if (correctedQuery != query) {
          final correctedResult = await semanticSearch(correctedQuery, options: options);
          return correctedResult.copyWith(
            correctedQuery: correctedQuery,
            originalQuery: query,
          );
        }
      }
      
      return result;
    } catch (e) {
      throw SearchException('Failed to search with autocorrect: $e');
    }
  }

  /// Get search history
  List<String> getSearchHistory() {
    return _searchCache.keys.toList()
      ..sort((a, b) => (_cacheTimestamps[b] ?? DateTime(0))
          .compareTo(_cacheTimestamps[a] ?? DateTime(0)));
  }

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
  }

  /// Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _apiClient.get('/search/health');
      return response.data;
    } catch (e) {
      return {
        'status': 'unhealthy',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Private helper methods

  SearchResult? _getCachedSearch(String query) {
    final cached = _searchCache[query];
    final timestamp = _cacheTimestamps[query];
    
    if (cached != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheTimeout) {
        return cached.copyWith(fromCache: true);
      } else {
        // Expired cache
        _searchCache.remove(query);
        _cacheTimestamps.remove(query);
      }
    }
    
    return null;
  }

  void _cacheSearch(String query, SearchResult result) {
    _searchCache[query] = result;
    _cacheTimestamps[query] = DateTime.now();
    
    // Limit cache size
    if (_searchCache.length > 50) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _searchCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  ReceiptSearchResult? _getCachedReceiptSearch(String query, ReceiptFilters? filters) {
    final cacheKey = '$query-${filters?.hashCode ?? 0}';
    final cached = _searchCache[cacheKey];
    final timestamp = _cacheTimestamps[cacheKey];
    
    if (cached != null && timestamp != null && cached is ReceiptSearchResult) {
      if (DateTime.now().difference(timestamp) < _cacheTimeout) {
        return cached.copyWith(fromCache: true) as ReceiptSearchResult;
      }
    }
    
    return null;
  }

  void _cacheReceiptSearch(String query, ReceiptFilters? filters, ReceiptSearchResult result) {
    final cacheKey = '$query-${filters?.hashCode ?? 0}';
    _searchCache[cacheKey] = result;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  void _invalidateCache(String query) {
    _searchCache.remove(query);
    _cacheTimestamps.remove(query);
  }

  bool _hasLikelyTypos(String query) {
    // Simple heuristics for typo detection
    final words = query.split(' ');
    return words.any((word) => 
        word.length > 4 && 
        word.contains(RegExp(r'(.)\1{2,}')) || // Repeated characters
        !word.contains(RegExp(r'[aeiou]', caseSensitive: false)) // No vowels
    );
  }

  String _attemptSpellCorrection(String query) {
    // Simple spell correction - in production would use a proper library
    final corrections = {
      'receit': 'receipt',
      'resturant': 'restaurant',
      'grocrey': 'grocery',
      'pharmace': 'pharmacy',
      'waranty': 'warranty',
      'guarante': 'guarantee',
    };

    String corrected = query;
    for (final entry in corrections.entries) {
      corrected = corrected.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    return corrected;
  }
}

/// Exception for search-related errors
class SearchException implements Exception {
  final String message;
  const SearchException(this.message);
  
  @override
  String toString() => 'SearchException: $message';
}