import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/promissory_note_model.dart';
import '../../models/company_model.dart';
import '../../services/firestore_service.dart';

class PromissoryNoteFormScreen extends StatefulWidget {
  final PromissoryNoteModel? note;

  const PromissoryNoteFormScreen({
    Key? key,
    this.note,
  }) : super(key: key);

  @override
  State<PromissoryNoteFormScreen> createState() => _PromissoryNoteFormScreenState();
}

class _PromissoryNoteFormScreenState extends State<PromissoryNoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _notesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedCompanyId;
  String? _selectedCompanyName;
  DateTime _purchaseDate = DateTime.now();
  DateTime _firstPaymentDate = DateTime.now();

  List<CompanyModel> _companies = [];
  List<PurchaseItem> _items = [];
  List<PaymentSchedule> _paymentSchedule = [];
  
  // Ürün controller'larını saklamak için Map
  final Map<int, TextEditingController> _descriptionControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _unitPriceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.note != null) {
      _items = List.from(widget.note!.items);
      _totalAmountController.text = widget.note!.totalAmount.toStringAsFixed(2);
      _installmentCountController.text = widget.note!.installmentCount.toString();
      _notesController.text = widget.note!.notes ?? '';
      _selectedCompanyId = widget.note!.companyId;
      _selectedCompanyName = widget.note!.companyName;
      _purchaseDate = widget.note!.purchaseDate;
      _firstPaymentDate = widget.note!.firstPaymentDate;
      _paymentSchedule = List.from(widget.note!.paymentSchedule);
    } else {
      _items = [PurchaseItem(description: '', quantity: 0, unitPrice: 0)];
      _totalAmountController.text = '0.0';
      _installmentCountController.text = '1';
    }
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _installmentCountController.dispose();
    _notesController.dispose();
    
    // Tüm item controller'larını temizle
    for (var controller in _descriptionControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _unitPriceControllers.values) {
      controller.dispose();
    }
    _descriptionControllers.clear();
    _quantityControllers.clear();
    _unitPriceControllers.clear();
    
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    _firestoreService.getAllCompanies().listen((companies) {
      if (mounted) {
        setState(() {
          _companies = companies;
          if (_selectedCompanyId != null && _companies.isNotEmpty) {
            final company = _companies.firstWhere(
              (c) => c.id == _selectedCompanyId,
              orElse: () => _companies.first,
            );
            _selectedCompanyName = company.name;
          }
        });
      }
    });
  }

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryOrange,
              onPrimary: AppColors.white,
              surface: AppColors.mediumGray,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
        if (_firstPaymentDate.isBefore(_purchaseDate)) {
          _firstPaymentDate = _purchaseDate;
        }
      });
    }
  }

  Future<void> _selectFirstPaymentDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstPaymentDate,
      firstDate: _purchaseDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryOrange,
              onPrimary: AppColors.white,
              surface: AppColors.mediumGray,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _firstPaymentDate) {
      setState(() {
        _firstPaymentDate = picked;
      });
    }
  }

  void _addItem() {
    setState(() {
      _items.add(PurchaseItem(description: '', quantity: 0, unitPrice: 0));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        // Controller'ları temizle
        _descriptionControllers[index]?.dispose();
        _quantityControllers[index]?.dispose();
        _unitPriceControllers[index]?.dispose();
        _descriptionControllers.remove(index);
        _quantityControllers.remove(index);
        _unitPriceControllers.remove(index);
        
        // Index'leri yeniden düzenle
        final newDescriptionControllers = <int, TextEditingController>{};
        final newQuantityControllers = <int, TextEditingController>{};
        final newUnitPriceControllers = <int, TextEditingController>{};
        
        for (int i = 0; i < _items.length; i++) {
          if (i < index) {
            if (_descriptionControllers.containsKey(i)) {
              newDescriptionControllers[i] = _descriptionControllers[i]!;
              newQuantityControllers[i] = _quantityControllers[i]!;
              newUnitPriceControllers[i] = _unitPriceControllers[i]!;
            }
          } else if (i > index) {
            if (_descriptionControllers.containsKey(i)) {
              newDescriptionControllers[i - 1] = _descriptionControllers[i]!;
              newQuantityControllers[i - 1] = _quantityControllers[i]!;
              newUnitPriceControllers[i - 1] = _unitPriceControllers[i]!;
            }
          }
        }
        
        _descriptionControllers.clear();
        _quantityControllers.clear();
        _unitPriceControllers.clear();
        _descriptionControllers.addAll(newDescriptionControllers);
        _quantityControllers.addAll(newQuantityControllers);
        _unitPriceControllers.addAll(newUnitPriceControllers);
        
        _items.removeAt(index);
      });
    }
  }

  void _updateItem(int index, PurchaseItem item) {
    // Controller'ları güncelle (sadece açıklama için, miktar ve fiyat kullanıcı yazarken güncellenmemeli)
    if (_descriptionControllers.containsKey(index)) {
      if (_descriptionControllers[index]!.text != item.description) {
        final currentSelection = _descriptionControllers[index]!.selection;
        _descriptionControllers[index]!.text = item.description;
        // Cursor pozisyonunu koru
        if (currentSelection.isValid) {
          final newOffset = currentSelection.baseOffset.clamp(0, item.description.length);
          _descriptionControllers[index]!.selection = TextSelection.collapsed(offset: newOffset);
        }
      }
    }
    // Miktar ve fiyat controller'larını güncelleme - kullanıcı yazarken bozulmasın
    // Sadece item'ı güncelle
    
    setState(() {
      _items[index] = item;
    });
  }
  
  TextEditingController _getDescriptionController(int index) {
    if (!_descriptionControllers.containsKey(index)) {
      _descriptionControllers[index] = TextEditingController(
        text: _items[index].description,
      );
    }
    return _descriptionControllers[index]!;
  }
  
  TextEditingController _getQuantityController(int index) {
    if (!_quantityControllers.containsKey(index)) {
      _quantityControllers[index] = TextEditingController(
        text: _items[index].quantity.toStringAsFixed(2),
      );
    }
    return _quantityControllers[index]!;
  }
  
  TextEditingController _getUnitPriceController(int index) {
    if (!_unitPriceControllers.containsKey(index)) {
      _unitPriceControllers[index] = TextEditingController(
        text: _items[index].unitPrice.toStringAsFixed(2),
      );
    }
    return _unitPriceControllers[index]!;
  }

  void _generatePaymentSchedule() {
    final installmentCount = int.tryParse(_installmentCountController.text) ?? 0;
    if (installmentCount < 1) return;

    // Virgülü noktaya çevir
    final totalAmountText = _totalAmountController.text.replaceAll(',', '.');
    final totalAmount = double.tryParse(totalAmountText) ?? 0.0;
    final installmentAmount = totalAmount / installmentCount;

    List<PaymentSchedule> schedule = [];
    for (int i = 0; i < installmentCount; i++) {
      DateTime dueDate;
      if (i == 0) {
        dueDate = _firstPaymentDate;
      } else {
        dueDate = DateTime(
          _firstPaymentDate.year,
          _firstPaymentDate.month + i,
          _firstPaymentDate.day,
        );
      }

      double amount = installmentAmount;
      if (i == installmentCount - 1) {
        double previousTotal = installmentAmount * (installmentCount - 1);
        amount = totalAmount - previousTotal;
      }

      // Mevcut ödeme durumunu koru
      bool isPaid = false;
      if (widget.note != null && i < widget.note!.paymentSchedule.length) {
        isPaid = widget.note!.paymentSchedule[i].isPaid;
      }

      schedule.add(PaymentSchedule(
        installmentNumber: i + 1,
        amount: amount,
        dueDate: dueDate,
        isPaid: isPaid,
      ));
    }

    setState(() {
      _paymentSchedule = schedule;
    });
  }

  Future<void> _editPaymentSchedule() async {
    if (_paymentSchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce taksit sayısını girin ve planı oluşturun'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScheduleEditor(
          paymentSchedule: List.from(_paymentSchedule),
          onSave: (schedule) {
            setState(() {
              _paymentSchedule = schedule;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir şirket seçin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Ürünlerin kontrolü
    bool hasValidItems = false;
    for (var item in _items) {
      if (item.description.trim().isNotEmpty) {
        hasValidItems = true;
        break;
      }
    }

    if (!hasValidItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir ürün eklemelisiniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Virgülü noktaya çevir
      final totalAmountText = _totalAmountController.text.trim().replaceAll(',', '.');
      final totalAmount = double.parse(totalAmountText);
      final installmentCount = int.parse(_installmentCountController.text.trim());

      if (installmentCount < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Taksit sayısı en az 1 olmalıdır'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_paymentSchedule.isEmpty || _paymentSchedule.length != installmentCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen ödeme planını oluşturun ve düzenleyin'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (widget.note == null) {
        // Yeni senet oluştur
        final note = PromissoryNoteModel(
          id: '',
          companyId: _selectedCompanyId!,
          companyName: _selectedCompanyName!,
          items: _items.where((item) => item.description.trim().isNotEmpty).toList(),
          totalAmount: totalAmount,
          installmentCount: installmentCount,
          purchaseDate: _purchaseDate,
          firstPaymentDate: _firstPaymentDate,
          paymentSchedule: _paymentSchedule,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestoreService.createPromissoryNote(note);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senet başarıyla eklendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Mevcut seneti güncelle
        await _firestoreService.updatePromissoryNote(
          widget.note!.id,
          {
            'company_id': _selectedCompanyId!,
            'company_name': _selectedCompanyName!,
            'items': _items.where((item) => item.description.trim().isNotEmpty).map((item) => item.toMap()).toList(),
            'total_amount': totalAmount,
            'installment_count': installmentCount,
            'purchase_date': Timestamp.fromDate(_purchaseDate),
            'first_payment_date': Timestamp.fromDate(_firstPaymentDate),
            'payment_schedule': _paymentSchedule.map((p) => p.toMap()).toList(),
            'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senet başarıyla güncellendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        // Hata mesajını daha anlaşılır hale getir
        String errorMessage = 'Senet kaydedilemedi';
        if (e.toString().contains('Senet kaydedilirken')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        } else if (e.toString().contains('Senet güncellenirken')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        } else {
          errorMessage = 'Bir hata oluştu: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      // Hata loglama (geliştirme için)
      debugPrint('PromissoryNote kaydetme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(widget.note == null ? 'Yeni Senet' : 'Senet Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Şirket Seçimi
              DropdownButtonFormField<String>(
                value: _selectedCompanyId,
                decoration: InputDecoration(
                  labelText: 'Şirket/Toptancı *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.business, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppColors.mediumGray,
                style: TextStyle(color: AppColors.white),
                items: _companies.map((company) {
                  return DropdownMenuItem<String>(
                    value: company.id,
                    child: Text(company.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCompanyId = value;
                    _selectedCompanyName = _companies.firstWhere((c) => c.id == value).name;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen bir şirket seçin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Ürünler Bölümü
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alınan Ürünler *',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: AppColors.primaryOrange),
                    onPressed: _addItem,
                    tooltip: 'Ürün Ekle',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._items.asMap().entries.map((entry) {
                int index = entry.key;
                PurchaseItem item = entry.value;
                return _buildItemCard(index, item);
              }).toList(),
              const SizedBox(height: 24),

              // Toplam Tutar (Manuel)
              TextFormField(
                controller: _totalAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    // Virgülü noktaya çevir (Türkçe klavye desteği)
                    String text = newValue.text.replaceAll(',', '.');
                    // Birden fazla nokta varsa sadece ilkini tut
                    int dotIndex = text.indexOf('.');
                    if (dotIndex != -1) {
                      text = text.substring(0, dotIndex + 1) + 
                             text.substring(dotIndex + 1).replaceAll('.', '');
                    }
                    return TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }),
                ],
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Toplam Tutar (₺) *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  helperText: 'Örn: 1000.50 veya 1000,50',
                  helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                ),
                onChanged: (value) {
                  // Virgülü noktaya çevir ve güncelle
                  if (value.isNotEmpty) {
                    final normalizedValue = value.replaceAll(',', '.');
                    if (normalizedValue != value) {
                      _totalAmountController.value = TextEditingValue(
                        text: normalizedValue,
                        selection: TextSelection.collapsed(offset: normalizedValue.length),
                      );
                    }
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Toplam tutarı girin';
                  }
                  // Virgülü noktaya çevir
                  final normalizedValue = value.replaceAll(',', '.');
                  final amount = double.tryParse(normalizedValue);
                  if (amount == null || amount <= 0) {
                    return 'Geçerli bir tutar girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Taksit Sayısı
              TextFormField(
                controller: _installmentCountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Kaç Taksit *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.payment, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Taksit sayısını girin';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Geçerli bir taksit sayısı girin (en az 1)';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Ödeme Planı Oluştur/Düzenle
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generatePaymentSchedule,
                      icon: Icon(Icons.schedule, color: AppColors.white),
                      label: Text('Plan Oluştur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _editPaymentSchedule,
                      icon: Icon(Icons.edit, color: AppColors.white),
                      label: Text('Planı Düzenle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGray,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (_paymentSchedule.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ödeme Planı:',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._paymentSchedule.map((payment) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taksit ${payment.installmentNumber}: ${DateFormat('dd.MM.yyyy').format(payment.dueDate)}',
                                style: TextStyle(color: AppColors.white),
                              ),
                              Text(
                                '${payment.amount.toStringAsFixed(2)} ₺',
                                style: TextStyle(
                                  color: payment.isPaid ? AppColors.statusCompleted : AppColors.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Alış Tarihi
              GestureDetector(
                onTap: () => _selectPurchaseDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.textGray),
                      const SizedBox(width: 12),
                      Text(
                        'Alış Tarihi: ${DateFormat('dd.MM.yyyy').format(_purchaseDate)}',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // İlk Ödeme Tarihi
              GestureDetector(
                onTap: () => _selectFirstPaymentDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: AppColors.textGray),
                      const SizedBox(width: 12),
                      Text(
                        'İlk Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(_firstPaymentDate)}',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notlar
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Notlar (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.note, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _saveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.note == null ? 'Kaydet' : 'Güncelle',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, PurchaseItem item) {
    // Controller'ları state'ten al (yeniden oluşturma)
    final descriptionController = _getDescriptionController(index);
    final quantityController = _getQuantityController(index);
    final unitPriceController = _getUnitPriceController(index);

    return Card(
      color: AppColors.mediumGray,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ürün ${index + 1}',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete, color: AppColors.error),
                    onPressed: () => _removeItem(index),
                    tooltip: 'Ürünü Sil',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              style: TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: 'Ürün Açıklaması *',
                labelStyle: TextStyle(color: AppColors.textGray),
                prefixIcon: Icon(Icons.description, color: AppColors.textGray),
                filled: true,
                fillColor: AppColors.darkGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _updateItem(index, item.copyWith(description: value));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        // Virgülü noktaya çevir (Türkçe klavye desteği)
                        String text = newValue.text.replaceAll(',', '.');
                        // Birden fazla nokta varsa sadece ilkini tut
                        int dotIndex = text.indexOf('.');
                        if (dotIndex != -1) {
                          text = text.substring(0, dotIndex + 1) + 
                                 text.substring(dotIndex + 1).replaceAll('.', '');
                        }
                        return TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(offset: text.length),
                        );
                      }),
                    ],
                    style: TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'Miktar',
                      labelStyle: TextStyle(color: AppColors.textGray),
                      prefixIcon: Icon(Icons.numbers, color: AppColors.textGray),
                      filled: true,
                      fillColor: AppColors.darkGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      helperText: 'Örn: 10 veya 10.5',
                      helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _updateItem(index, item.copyWith(quantity: 0.0));
                        return;
                      }
                      // Virgülü noktaya çevir
                      final normalizedValue = value.replaceAll(',', '.');
                      final qty = double.tryParse(normalizedValue);
                      if (qty != null && qty >= 0) {
                        _updateItem(index, item.copyWith(quantity: qty));
                        // Formatlamayı güncelle (sadece değer değiştiyse)
                        if (quantityController.text != normalizedValue && 
                            (qty.toStringAsFixed(2) != normalizedValue || !normalizedValue.contains('.'))) {
                          // Kullanıcı yazmaya devam ediyorsa formatlamayı bozma
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        // Virgülü noktaya çevir (Türkçe klavye desteği)
                        String text = newValue.text.replaceAll(',', '.');
                        // Birden fazla nokta varsa sadece ilkini tut
                        int dotIndex = text.indexOf('.');
                        if (dotIndex != -1) {
                          text = text.substring(0, dotIndex + 1) + 
                                 text.substring(dotIndex + 1).replaceAll('.', '');
                        }
                        return TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(offset: text.length),
                        );
                      }),
                    ],
                    style: TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'Birim Fiyat (₺)',
                      labelStyle: TextStyle(color: AppColors.textGray),
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                      filled: true,
                      fillColor: AppColors.darkGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      helperText: 'Örn: 100.50 veya 100,50',
                      helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _updateItem(index, item.copyWith(unitPrice: 0.0));
                        return;
                      }
                      // Virgülü noktaya çevir
                      final normalizedValue = value.replaceAll(',', '.');
                      final price = double.tryParse(normalizedValue);
                      if (price != null && price >= 0) {
                        _updateItem(index, item.copyWith(unitPrice: price));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ara Toplam: ${item.subtotal.toStringAsFixed(2)} ₺',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ödeme Planı Düzenleme Ekranı
class PaymentScheduleEditor extends StatefulWidget {
  final List<PaymentSchedule> paymentSchedule;
  final Function(List<PaymentSchedule>) onSave;

  const PaymentScheduleEditor({
    Key? key,
    required this.paymentSchedule,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PaymentScheduleEditor> createState() => _PaymentScheduleEditorState();
}

class _PaymentScheduleEditorState extends State<PaymentScheduleEditor> {
  late List<PaymentSchedule> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = List.from(widget.paymentSchedule);
  }

  Future<void> _selectDate(int index, DateTime currentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryOrange,
              onPrimary: AppColors.white,
              surface: AppColors.mediumGray,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _schedule[index] = _schedule[index].copyWith(dueDate: picked);
      });
    }
  }

  void _updateAmount(int index, String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _schedule[index] = _schedule[index].copyWith(amount: amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Ödeme Planını Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              widget.onSave(_schedule);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._schedule.asMap().entries.map((entry) {
            int index = entry.key;
            PaymentSchedule payment = entry.value;
            final amountController = TextEditingController(text: payment.amount.toStringAsFixed(2));

            return Card(
              color: AppColors.mediumGray,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Taksit ${payment.installmentNumber}',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (payment.isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.statusCompleted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ÖDENDİ',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺) *',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => _updateAmount(index, value),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _selectDate(index, payment.dueDate),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppColors.textGray),
                            const SizedBox(width: 12),
                            Text(
                              'Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(payment.dueDate)}',
                              style: TextStyle(color: AppColors.white),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: AppColors.textGray),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
