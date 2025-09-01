import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/constants/app_constants.dart';

class ReceiptFormData {
  String merchantName;
  double totalAmount;
  String category;
  DateTime date;
  String? notes;

  ReceiptFormData({
    this.merchantName = '',
    this.totalAmount = 0.0,
    this.category = 'Other',
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  ReceiptFormData copyWith({
    String? merchantName,
    double? totalAmount,
    String? category,
    DateTime? date,
    String? notes,
  }) {
    return ReceiptFormData(
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}

class ReceiptForm extends StatefulWidget {
  final ReceiptFormData initialData;
  final List<String> availableCategories;
  final ValueChanged<ReceiptFormData> onChanged;
  final VoidCallback? onSubmit;
  final String submitButtonText;
  final bool isLoading;

  const ReceiptForm({
    super.key,
    required this.initialData,
    this.availableCategories = AppConstants.defaultCategories,
    required this.onChanged,
    this.onSubmit,
    this.submitButtonText = 'Save Receipt',
    this.isLoading = false,
  });

  @override
  State<ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<ReceiptForm> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  late ReceiptFormData _formData;
  final _currencyFormat = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    _formData = widget.initialData;
    
    _merchantController.text = _formData.merchantName;
    _amountController.text = _formData.totalAmount > 0 
        ? _formData.totalAmount.toStringAsFixed(2)
        : '';
    _notesController.text = _formData.notes ?? '';
    
    _merchantController.addListener(_updateMerchantName);
    _amountController.addListener(_updateAmount);
    _notesController.addListener(_updateNotes);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateMerchantName() {
    _formData = _formData.copyWith(merchantName: _merchantController.text);
    widget.onChanged(_formData);
  }

  void _updateAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    _formData = _formData.copyWith(totalAmount: amount);
    widget.onChanged(_formData);
  }

  void _updateNotes() {
    _formData = _formData.copyWith(notes: _notesController.text);
    widget.onChanged(_formData);
  }

  void _updateCategory(String? category) {
    if (category != null) {
      setState(() {
        _formData = _formData.copyWith(category: category);
        widget.onChanged(_formData);
      });
    }
  }

  void _updateDate(DateTime date) {
    setState(() {
      _formData = _formData.copyWith(date: date);
      widget.onChanged(_formData);
    });
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _formData.date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (selectedDate != null) {
      _updateDate(selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Merchant Name
          TextFormField(
            controller: _merchantController,
            decoration: const InputDecoration(
              labelText: 'Merchant Name',
              hintText: 'Enter store or restaurant name',
              prefixIcon: Icon(Icons.store),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter merchant name';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Amount
          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Total Amount',
              hintText: '0.00',
              prefixIcon: const Icon(Icons.attach_money),
              prefixText: _currencyFormat.currencySymbol,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter amount';
              }
              final amount = double.tryParse(value!);
              if (amount == null || amount <= 0) {
                return 'Please enter valid amount';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Category Dropdown
          DropdownButtonFormField<String>(
            value: _formData.category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
            ),
            items: widget.availableCategories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      size: 20,
                      color: _getCategoryColor(category),
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Text(category),
                  ],
                ),
              );
            }).toList(),
            onChanged: _updateCategory,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please select category';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Date Picker
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                DateFormat('MMMM dd, yyyy').format(_formData.date),
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Notes (Optional)
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional notes...',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Submit Button
          if (widget.onSubmit != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : () {
                  if (_formKey.currentState?.validate() ?? false) {
                    widget.onSubmit!();
                  }
                },
                child: widget.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(widget.submitButtonText),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'transportation':
        return Icons.directions_car;
      case 'healthcare':
        return Icons.local_hospital;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
        return Icons.bolt;
      case 'education':
        return Icons.school;
      case 'home & garden':
        return Icons.home;
      case 'travel':
        return Icons.flight;
      case 'business':
        return Icons.business;
      default:
        return Icons.receipt;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Colors.orange;
      case 'shopping':
        return Colors.blue;
      case 'transportation':
        return Colors.green;
      case 'healthcare':
        return Colors.red;
      case 'entertainment':
        return Colors.purple;
      case 'utilities':
        return Colors.brown;
      case 'education':
        return Colors.indigo;
      case 'home & garden':
        return Colors.teal;
      case 'travel':
        return Colors.cyan;
      case 'business':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}

class ReceiptFormField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? error;

  const ReceiptFormField({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        child,
        if (error != null) ...[
          const SizedBox(height: AppTheme.spacingXSmall),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ],
    );
  }
}