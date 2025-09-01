import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/receipt_provider.dart';
import '../widgets/receipt_form.dart';
import '../services/ocr_service.dart';

class AddReceiptScreen extends ConsumerStatefulWidget {
  const AddReceiptScreen({super.key});

  @override
  ConsumerState<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends ConsumerState<AddReceiptScreen> {
  final _imagePicker = ImagePicker();
  
  File? _selectedImage;
  ReceiptFormData _formData = ReceiptFormData();
  bool _isProcessingImage = false;
  String? _ocrError;

  @override
  Widget build(BuildContext context) {
    final receiptState = ref.watch(receiptProvider);
    final categories = receiptState.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Receipt'),
        actions: [
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearImage,
              tooltip: 'Clear image',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image capture section
            _buildImageSection(),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Manual entry form
            _buildFormSection(categories),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Receipt Image',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            if (_selectedImage == null) _buildImageCapture() else _buildImagePreview(),
            
            if (_ocrError != null) ...[
              const SizedBox(height: AppTheme.spacingSmall),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingSmall),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Expanded(
                      child: Text(
                        _ocrError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCapture() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            color: Colors.grey.shade50,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                'Add receipt image',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXSmall),
              Text(
                'Take a photo or select from gallery',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        if (_isProcessingImage)
          Column(
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                'Processing image with OCR...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Change'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFormSection(List<String> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Receipt Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            ReceiptForm(
              initialData: _formData,
              availableCategories: categories,
              onChanged: (data) {
                setState(() {
                  _formData = data;
                });
              },
              onSubmit: _saveReceipt,
              submitButtonText: 'Save Receipt',
              isLoading: ref.watch(receiptProvider).isCreating,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check permissions
      if (source == ImageSource.camera) {
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          _showPermissionError('Camera permission is required to take photos');
          return;
        }
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _ocrError = null;
          _isProcessingImage = true;
        });

        // Process image with OCR
        await _processImageWithOCR();
      }
    } catch (e) {
      _showError('Failed to capture image: ${e.toString()}');
    }
  }

  Future<void> _processImageWithOCR() async {
    if (_selectedImage == null) return;

    try {
      final ocrData = await OCRService.processReceiptImage(
        imagePath: _selectedImage!.path,
      );

      setState(() {
        _formData = _formData.copyWith(
          merchantName: ocrData.merchantName.isNotEmpty 
              ? ocrData.merchantName 
              : _formData.merchantName,
          totalAmount: ocrData.totalAmount > 0 
              ? ocrData.totalAmount 
              : _formData.totalAmount,
          category: ocrData.category.isNotEmpty 
              ? ocrData.category 
              : _formData.category,
          date: ocrData.date,
        );
        _isProcessingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt processed successfully! '
              'Confidence: ${(ocrData.confidence * 100).round()}%',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
        _ocrError = 'Failed to process image: ${e.toString()}';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _ocrError = null;
      _isProcessingImage = false;
    });
  }

  Future<void> _saveReceipt() async {
    if (_selectedImage == null) {
      _showError('Please add a receipt image');
      return;
    }

    final receipt = await ref.read(receiptProvider.notifier).createReceipt(
      imagePath: _selectedImage!.path,
      merchantName: _formData.merchantName,
      totalAmount: _formData.totalAmount,
      category: _formData.category,
      date: _formData.date,
    );

    if (receipt != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt saved successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      context.pushReplacement(
        RoutePaths.receiptDetailPath(receipt.id),
      );
    } else if (mounted) {
      final error = ref.read(receiptProvider).error;
      _showError(error ?? 'Failed to save receipt');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showPermissionError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}