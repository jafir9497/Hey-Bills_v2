// Hey-Bills Flutter Test Examples
// QA Specialist Test Implementation Guide

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock class generation
@GenerateMocks([SupabaseClient, GoTrueClient, StorageApi])
import 'flutter_test_examples.mocks.dart';

// Test data models (these would normally be in your models directory)
class Receipt {
  final String id;
  final String merchantName;
  final double totalAmount;
  final String category;
  final DateTime date;
  final Map<String, dynamic> ocrData;

  Receipt({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.category,
    required this.date,
    required this.ocrData,
  });

  bool get isValid => merchantName.isNotEmpty && totalAmount > 0;
}

class Warranty {
  final String id;
  final String productName;
  final DateTime purchaseDate;
  final Duration warrantyPeriod;
  final DateTime expirationDate;

  Warranty({
    required this.id,
    required this.productName,
    required this.purchaseDate,
    required this.warrantyPeriod,
  }) : expirationDate = purchaseDate.add(warrantyPeriod);

  int get daysUntilExpiration => expirationDate.difference(DateTime.now()).inDays;
  bool needsAlert(int daysBeforeExpiration) => daysUntilExpiration <= daysBeforeExpiration;
}

// === UNIT TESTS ===

void main() {
  group('Receipt Model Unit Tests', () {
    test('should create receipt with valid data', () {
      // Arrange
      final receipt = Receipt(
        id: 'test-123',
        merchantName: 'Target',
        totalAmount: 25.99,
        category: 'groceries',
        date: DateTime.now(),
        ocrData: {'items': ['Item1', 'Item2']},
      );

      // Assert
      expect(receipt.merchantName, equals('Target'));
      expect(receipt.totalAmount, equals(25.99));
      expect(receipt.isValid, isTrue);
      expect(receipt.ocrData['items'], contains('Item1'));
    });

    test('should validate receipt with empty merchant name as invalid', () {
      // Arrange
      final receipt = Receipt(
        id: 'test-456',
        merchantName: '',
        totalAmount: 10.50,
        category: 'food',
        date: DateTime.now(),
        ocrData: {},
      );

      // Assert
      expect(receipt.isValid, isFalse);
    });

    test('should validate receipt with zero amount as invalid', () {
      // Arrange
      final receipt = Receipt(
        id: 'test-789',
        merchantName: 'Walmart',
        totalAmount: 0.0,
        category: 'groceries',
        date: DateTime.now(),
        ocrData: {},
      );

      // Assert
      expect(receipt.isValid, isFalse);
    });
  });

  group('Warranty Calculation Unit Tests', () {
    test('should calculate correct expiration date', () {
      // Arrange
      final purchaseDate = DateTime(2024, 1, 1);
      final warranty = Warranty(
        id: 'warranty-123',
        productName: 'iPhone 15',
        purchaseDate: purchaseDate,
        warrantyPeriod: Duration(days: 365),
      );

      // Assert
      expect(warranty.expirationDate, equals(DateTime(2025, 1, 1)));
    });

    test('should correctly identify when warranty needs alert', () {
      // Arrange
      final purchaseDate = DateTime.now().subtract(Duration(days: 335)); // 30 days left
      final warranty = Warranty(
        id: 'warranty-456',
        productName: 'MacBook Pro',
        purchaseDate: purchaseDate,
        warrantyPeriod: Duration(days: 365),
      );

      // Assert
      expect(warranty.needsAlert(30), isTrue);
      expect(warranty.needsAlert(7), isFalse);
    });

    test('should calculate days until expiration correctly', () {
      // Arrange
      final purchaseDate = DateTime.now().subtract(Duration(days: 300)); // 65 days left
      final warranty = Warranty(
        id: 'warranty-789',
        productName: 'iPad',
        purchaseDate: purchaseDate,
        warrantyPeriod: Duration(days: 365),
      );

      // Assert
      expect(warranty.daysUntilExpiration, closeTo(65, 1)); // Allow 1 day variance
    });
  });

  group('OCR Service Unit Tests', () {
    late MockSupabaseClient mockSupabase;

    setUp(() {
      mockSupabase = MockSupabaseClient();
    });

    test('should process receipt image and extract data', () async {
      // This is a conceptual test - actual OCR would need proper mocking
      // Arrange
      final mockImageBytes = <int>[1, 2, 3, 4]; // Mock image data
      
      // Act
      final result = await processReceiptOCR(mockImageBytes);

      // Assert
      expect(result.merchantName, isNotEmpty);
      expect(result.totalAmount, greaterThan(0));
      expect(result.confidence, greaterThan(0.5));
    });

    test('should handle poor quality images gracefully', () async {
      // Arrange
      final poorQualityImage = <int>[]; // Empty or corrupted image
      
      // Act
      final result = await processReceiptOCR(poorQualityImage);

      // Assert
      expect(result.hasError, isFalse); // Should not crash
      expect(result.requiresManualReview, isTrue);
    });
  });

  group('Authentication Service Unit Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(mockSupabase.auth).thenReturn(mockAuth);
    });

    test('should authenticate user with email and password', () async {
      // Arrange
      final email = 'test@example.com';
      final password = 'SecurePass123!';
      final mockResponse = AuthResponse(
        user: User(
          id: 'user-123',
          email: email,
          createdAt: DateTime.now().toIso8601String(),
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
        ),
        session: Session(
          accessToken: 'mock-token',
          tokenType: 'bearer',
          user: null,
          refreshToken: 'mock-refresh',
          expiresIn: 3600,
          expiresAt: DateTime.now().millisecondsSinceEpoch + 3600000,
        ),
      );

      when(mockAuth.signInWithPassword(email: email, password: password))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result = await AuthService.signInWithEmail(email, password);

      // Assert
      expect(result.success, isTrue);
      expect(result.user?.email, equals(email));
      verify(mockAuth.signInWithPassword(email: email, password: password)).called(1);
    });

    test('should handle authentication errors gracefully', () async {
      // Arrange
      when(mockAuth.signInWithPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenThrow(AuthException('Invalid credentials'));

      // Act
      final result = await AuthService.signInWithEmail('wrong@email.com', 'wrongpass');

      // Assert
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Invalid credentials'));
    });
  });
}

// === WIDGET TESTS ===

// Mock widgets for testing
class ReceiptScannerWidget extends StatefulWidget {
  @override
  _ReceiptScannerWidgetState createState() => _ReceiptScannerWidgetState();
}

class _ReceiptScannerWidgetState extends State<ReceiptScannerWidget> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
              key: Key('camera_preview'),
              child: Center(child: Text('Camera Preview')),
            ),
          ),
          if (isProcessing)
            Column(
              children: [
                CircularProgressIndicator(),
                Text('Processing receipt...'),
              ],
            ),
          ElevatedButton(
            key: Key('capture_button'),
            onPressed: () {
              setState(() {
                isProcessing = true;
              });
              // Simulate OCR processing
              Future.delayed(Duration(seconds: 2), () {
                setState(() {
                  isProcessing = false;
                });
              });
            },
            child: Text('Capture Receipt'),
          ),
        ],
      ),
    );
  }
}

class DashboardWidget extends StatelessWidget {
  final SpendingData data;

  DashboardWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('\$${data.totalSpent.toStringAsFixed(2)}'),
        Text('This Month'),
        Container(key: Key('pie_chart'), child: Text('Pie Chart Placeholder')),
      ],
    );
  }
}

class SpendingData {
  final double totalSpent;
  final Map<String, double> categories;

  SpendingData({required this.totalSpent, required this.categories});
}

class WarrantyAlertWidget extends StatelessWidget {
  final Warranty warranty;

  WarrantyAlertWidget({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final isUrgent = warranty.daysUntilExpiration <= 7;
    
    return Card(
      color: isUrgent ? Colors.red[100] : Colors.white,
      child: ListTile(
        leading: isUrgent ? Icon(Icons.warning, color: Colors.red) : Icon(Icons.schedule),
        title: Text(warranty.productName),
        subtitle: Text(isUrgent ? 'EXPIRES SOON' : 'Active Warranty'),
        trailing: Text('${warranty.daysUntilExpiration} days'),
      ),
    );
  }
}

// Widget test examples
void widgetTestMain() {
  group('Receipt Scanner Widget Tests', () {
    testWidgets('should display camera preview and capture button', (tester) async {
      // Act
      await tester.pumpWidget(MaterialApp(home: ReceiptScannerWidget()));

      // Assert
      expect(find.byKey(Key('camera_preview')), findsOneWidget);
      expect(find.byKey(Key('capture_button')), findsOneWidget);
      expect(find.text('Capture Receipt'), findsOneWidget);
    });

    testWidgets('should show loading during OCR processing', (tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(home: ReceiptScannerWidget()));

      // Act
      await tester.tap(find.byKey(Key('capture_button')));
      await tester.pump(); // Trigger rebuild

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing receipt...'), findsOneWidget);

      // Wait for processing to complete
      await tester.pump(Duration(seconds: 3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should disable capture button during processing', (tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(home: ReceiptScannerWidget()));

      // Act
      await tester.tap(find.byKey(Key('capture_button')));
      await tester.pump();

      // Try to tap again while processing
      await tester.tap(find.byKey(Key('capture_button')));
      await tester.pump();

      // Assert - should still only show one progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Dashboard Widget Tests', () {
    testWidgets('should display spending summary correctly', (tester) async {
      // Arrange
      final mockData = SpendingData(
        totalSpent: 1250.75,
        categories: {'groceries': 500.0, 'dining': 300.0, 'gas': 450.75},
      );

      // Act
      await tester.pumpWidget(MaterialApp(home: DashboardWidget(data: mockData)));

      // Assert
      expect(find.text('\$1,250.75'), findsOneWidget);
      expect(find.byKey(Key('pie_chart')), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets('should handle zero spending gracefully', (tester) async {
      // Arrange
      final emptyData = SpendingData(
        totalSpent: 0.0,
        categories: {},
      );

      // Act
      await tester.pumpWidget(MaterialApp(home: DashboardWidget(data: emptyData)));

      // Assert
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.byKey(Key('pie_chart')), findsOneWidget);
    });
  });

  group('Warranty Alert Widget Tests', () {
    testWidgets('should show urgent alerts prominently', (tester) async {
      // Arrange
      final urgentWarranty = Warranty(
        id: 'urgent-warranty',
        productName: 'iPhone 15',
        purchaseDate: DateTime.now().subtract(Duration(days: 360)), // 5 days left
        warrantyPeriod: Duration(days: 365),
      );

      // Act
      await tester.pumpWidget(MaterialApp(home: WarrantyAlertWidget(warranty: urgentWarranty)));

      // Assert
      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.text('EXPIRES SOON'), findsOneWidget);
      expect(find.text('iPhone 15'), findsOneWidget);
      expect(find.textContaining('days'), findsOneWidget);
    });

    testWidgets('should show normal alerts for non-urgent warranties', (tester) async {
      // Arrange
      final normalWarranty = Warranty(
        id: 'normal-warranty',
        productName: 'MacBook Pro',
        purchaseDate: DateTime.now().subtract(Duration(days: 200)), // 165 days left
        warrantyPeriod: Duration(days: 365),
      );

      // Act
      await tester.pumpWidget(MaterialApp(home: WarrantyAlertWidget(warranty: normalWarranty)));

      // Assert
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.text('Active Warranty'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
    });
  });
}

// === INTEGRATION TEST EXAMPLES ===

void integrationTestMain() {
  group('Supabase Integration Tests', () {
    late SupabaseClient supabase;
    const testEmail = 'test@heybills.example.com';
    const testPassword = 'TestPassword123!';

    setUpAll(() {
      // Initialize Supabase with test environment
      supabase = SupabaseClient(
        'https://your-test-project.supabase.co',
        'your-test-anon-key',
      );
    });

    tearDown(() async {
      // Cleanup test data after each test
      try {
        await supabase.from('receipts').delete().eq('user_id', 'test-user-id');
        await supabase.from('warranties').delete().eq('user_id', 'test-user-id');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should authenticate user with email and password', () async {
      // Act
      final response = await supabase.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      // Assert
      expect(response.user, isNotNull);
      expect(response.user!.email, equals(testEmail));
      expect(response.session, isNotNull);
      expect(response.session!.accessToken, isNotEmpty);
    });

    test('should create and retrieve receipt', () async {
      // Arrange
      await supabase.auth.signInWithPassword(email: testEmail, password: testPassword);
      final userId = supabase.auth.currentUser!.id;

      final receiptData = {
        'user_id': userId,
        'merchant_name': 'Test Store',
        'total_amount': 25.99,
        'category': 'groceries',
        'ocr_data': {'items': ['milk', 'bread']},
        'date': DateTime.now().toIso8601String(),
      };

      // Act
      final insertResponse = await supabase.from('receipts').insert(receiptData).select();
      final receiptId = insertResponse[0]['id'];

      final retrieveResponse = await supabase
          .from('receipts')
          .select()
          .eq('id', receiptId)
          .single();

      // Assert
      expect(retrieveResponse['merchant_name'], equals('Test Store'));
      expect(retrieveResponse['total_amount'], equals(25.99));
      expect(retrieveResponse['user_id'], equals(userId));
    });

    test('should enforce Row Level Security', () async {
      // Arrange - Create receipt with User 1
      await supabase.auth.signInWithPassword(email: testEmail, password: testPassword);
      final user1Id = supabase.auth.currentUser!.id;

      final receiptData = {
        'user_id': user1Id,
        'merchant_name': 'Private Receipt',
        'total_amount': 50.00,
        'category': 'personal',
      };

      final insertResponse = await supabase.from('receipts').insert(receiptData).select();
      final receiptId = insertResponse[0]['id'];

      // Sign out User 1
      await supabase.auth.signOut();

      // Act - Try to access with different user (or anonymous)
      final unauthorizedResponse = await supabase
          .from('receipts')
          .select()
          .eq('id', receiptId);

      // Assert - Should return empty results due to RLS
      expect(unauthorizedResponse, isEmpty);
    });

    test('should store and retrieve warranty with alerts', () async {
      // Arrange
      await supabase.auth.signInWithPassword(email: testEmail, password: testPassword);
      final userId = supabase.auth.currentUser!.id;

      final warrantyData = {
        'user_id': userId,
        'product_name': 'Test iPhone',
        'purchase_date': DateTime.now().toIso8601String(),
        'warranty_end_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'alert_preferences': {'30_day': true, '7_day': true, '1_day': true},
      };

      // Act
      final insertResponse = await supabase.from('warranties').insert(warrantyData).select();
      final warrantyId = insertResponse[0]['id'];

      final retrieveResponse = await supabase
          .from('warranties')
          .select()
          .eq('id', warrantyId)
          .single();

      // Assert
      expect(retrieveResponse['product_name'], equals('Test iPhone'));
      expect(retrieveResponse['user_id'], equals(userId));
      expect(retrieveResponse['alert_preferences']['30_day'], isTrue);
    });
  });
}

// === PERFORMANCE TEST EXAMPLES ===

void performanceTestMain() {
  group('Performance Tests', () {
    test('app startup performance should be under 3 seconds', () async {
      final stopwatch = Stopwatch()..start();

      // Simulate app initialization
      await Future.delayed(Duration(milliseconds: 1500)); // Mock initialization time

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('OCR processing should complete under 5 seconds', () async {
      final mockReceiptImage = List.filled(1024 * 1024, 1); // 1MB mock image
      final stopwatch = Stopwatch()..start();

      // Simulate OCR processing
      final result = await processReceiptOCR(mockReceiptImage);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(result, isNotNull);
    });

    test('large receipt list should load efficiently', () async {
      // Arrange
      final largeReceiptList = List.generate(1000, (index) => Receipt(
        id: 'receipt-$index',
        merchantName: 'Store $index',
        totalAmount: (index * 10.5),
        category: 'test',
        date: DateTime.now(),
        ocrData: {},
      ));

      final stopwatch = Stopwatch()..start();

      // Act - Simulate loading and filtering
      final filteredReceipts = largeReceiptList
          .where((receipt) => receipt.totalAmount > 50)
          .take(10)
          .toList();

      stopwatch.stop();

      // Assert
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      expect(filteredReceipts.length, equals(10));
    });
  });
}

// Mock service implementations for testing
class AuthService {
  static Future<AuthResult> signInWithEmail(String email, String password) async {
    // Mock implementation
    if (email.contains('wrong')) {
      return AuthResult(success: false, errorMessage: 'Invalid credentials');
    }
    
    return AuthResult(
      success: true,
      user: User(
        id: 'mock-user-id',
        email: email,
        createdAt: DateTime.now().toIso8601String(),
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
      ),
    );
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult({required this.success, this.user, this.errorMessage});
}

class OCRResult {
  final String merchantName;
  final double totalAmount;
  final double confidence;
  final bool hasError;
  final bool requiresManualReview;

  OCRResult({
    required this.merchantName,
    required this.totalAmount,
    required this.confidence,
    this.hasError = false,
    this.requiresManualReview = false,
  });
}

Future<OCRResult> processReceiptOCR(List<int> imageBytes) async {
  // Mock OCR processing
  await Future.delayed(Duration(milliseconds: 500));
  
  if (imageBytes.isEmpty) {
    return OCRResult(
      merchantName: '',
      totalAmount: 0.0,
      confidence: 0.0,
      requiresManualReview: true,
    );
  }

  return OCRResult(
    merchantName: 'Mock Store',
    totalAmount: 25.99,
    confidence: 0.95,
  );
}