import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/company_model.dart';
import '../../models/promissory_note_model.dart';
import '../../services/firestore_service.dart';
import 'company_form_screen.dart';
import 'promissory_note_form_screen.dart';
import '../../widgets/cached_network_image_widget.dart';

class AdminCompaniesScreen extends StatefulWidget {
  const AdminCompaniesScreen({Key? key}) : super(key: key);

  @override
  State<AdminCompaniesScreen> createState() => _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends State<AdminCompaniesScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  String _companySearchQuery = '';
  String _promissoryNoteSearchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Tab değiştiğinde UI'ı güncelle
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteDialog(BuildContext context, CompanyModel company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Şirketi Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            '${company.name} adlı şirketi silmek istediğinizden emin misiniz?',
            style: TextStyle(color: AppColors.textGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Sil',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await _firestoreService.deleteCompany(company.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şirket başarıyla silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryOrange,
        unselectedLabelColor: AppColors.textGray,
        indicatorColor: AppColors.primaryOrange,
        tabs: const [
          Tab(text: 'Şirketler'),
          Tab(text: 'Senetler'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCompaniesTab(),
          _buildPromissoryNotesTab(),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return _tabController.index == 0
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompanyFormScreen(),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primaryOrange,
                  child: const Icon(Icons.add, color: AppColors.white),
                )
              : FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PromissoryNoteFormScreen(),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primaryOrange,
                  child: const Icon(Icons.receipt_long, color: AppColors.white),
                );
        },
      ),
    );
  }

  Widget _buildCompaniesTab() {
    return Column(
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _companySearchQuery = value.toLowerCase();
              });
            },
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Şirket adı ile ara...',
              hintStyle: TextStyle(color: AppColors.textGray),
              prefixIcon: Icon(Icons.search, color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Şirket Listesi
        Expanded(
          child: StreamBuilder<List<CompanyModel>>(
              stream: _firestoreService.getAllCompanies(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Hata: ${snapshot.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                var companies = snapshot.data ?? [];

                // Arama filtresi uygula
                if (_companySearchQuery.isNotEmpty) {
                  companies = companies.where((company) {
                    return company.name.toLowerCase().contains(_companySearchQuery);
                  }).toList();
                }

                // Net değere göre sırala (borç - alacak, en çok borçlu önce)
                companies.sort((a, b) {
                  double aNet = a.debt - a.receivable;
                  double bNet = b.debt - b.receivable;
                  return bNet.compareTo(aNet);
                });

                if (companies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business,
                          size: 64,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _companySearchQuery.isEmpty
                              ? 'Henüz şirket eklenmemiş'
                              : 'Arama sonucu bulunamadı',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Toplam borç ve alacak hesapla
                double totalDebt = 0;
                double totalReceivable = 0;
                for (var company in companies) {
                  totalDebt += company.debt;
                  totalReceivable += company.receivable;
                }
                double netTotal = totalDebt - totalReceivable;

                return Column(
                  children: [
                    // Toplam Özet Kartı
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.mediumGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: netTotal > 0
                              ? AppColors.error.withOpacity(0.3)
                              : AppColors.statusCompleted.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Toplam Borç',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${totalDebt.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Toplam Alacak',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${totalReceivable.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.statusCompleted,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.textGray, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Net Durum',
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${netTotal.abs().toStringAsFixed(2)} ₺',
                                style: TextStyle(
                                  color: netTotal > 0
                                      ? AppColors.error
                                      : netTotal < 0
                                          ? AppColors.statusCompleted
                                          : AppColors.textGray,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (netTotal != 0)
                            Text(
                              netTotal > 0 ? 'Borçlu' : 'Alacaklı',
                              style: TextStyle(
                                color: netTotal > 0
                                    ? AppColors.error
                                    : AppColors.statusCompleted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ListView
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final company = companies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppColors.mediumGray,
                            child: ExpansionTile(
                              leading: company.photoUrl != null
                                  ? ClipOval(
                                      child: CachedNetworkImageWidget(
                                        imageUrl: company.photoUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: (company.debt - company.receivable) > 0
                                          ? AppColors.error
                                          : company.receivable > company.debt
                                              ? AppColors.statusCompleted
                                              : AppColors.textGray,
                                      child: Icon(
                                        Icons.business,
                                        color: AppColors.white,
                                      ),
                                    ),
                              title: Text(
                                company.name,
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Builder(
                                builder: (context) {
                                  double net = company.debt - company.receivable;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (company.debt > 0)
                                        Text(
                                          'Borç: ${company.debt.toStringAsFixed(2)} ₺',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (company.receivable > 0)
                                        Text(
                                          'Alacak: ${company.receivable.toStringAsFixed(2)} ₺',
                                          style: TextStyle(
                                            color: AppColors.statusCompleted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (company.debt == 0 && company.receivable == 0)
                                        Text(
                                          'Borç/Alacak Yok',
                                          style: TextStyle(
                                            color: AppColors.textGray,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (net != 0)
                                        Text(
                                          'Net: ${net.abs().toStringAsFixed(2)} ₺ ${net > 0 ? "Borçlu" : "Alacaklı"}',
                                          style: TextStyle(
                                            color: net > 0 ? AppColors.error : AppColors.statusCompleted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // İletişim Bilgileri
                                      if (company.contactPerson != null ||
                                          company.phone != null ||
                                          company.email != null) ...[
                                        Text(
                                          'İletişim Bilgileri',
                                          style: TextStyle(
                                            color: AppColors.primaryOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (company.contactPerson != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Icon(Icons.person, color: AppColors.textGray, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  company.contactPerson!,
                                                  style: TextStyle(color: AppColors.white),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (company.phone != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Icon(Icons.phone, color: AppColors.textGray, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  company.phone!,
                                                  style: TextStyle(color: AppColors.white),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (company.email != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Icon(Icons.email, color: AppColors.textGray, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  company.email!,
                                                  style: TextStyle(color: AppColors.white),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const Divider(color: AppColors.textGray),
                                      ],

                                      // Borç ve Alacak
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Borç:',
                                            style: TextStyle(
                                              color: AppColors.textGray,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${company.debt.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              color: company.debt > 0
                                                  ? AppColors.error
                                                  : AppColors.textGray,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Alacak:',
                                            style: TextStyle(
                                              color: AppColors.textGray,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${company.receivable.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              color: company.receivable > 0
                                                  ? AppColors.statusCompleted
                                                  : AppColors.textGray,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: AppColors.textGray, height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Net:',
                                            style: TextStyle(
                                              color: AppColors.primaryOrange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          Text(
                                            '${(company.debt - company.receivable).abs().toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              color: (company.debt - company.receivable) > 0
                                                  ? AppColors.error
                                                  : (company.debt - company.receivable) < 0
                                                      ? AppColors.statusCompleted
                                                      : AppColors.textGray,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((company.debt - company.receivable) != 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            (company.debt - company.receivable) > 0
                                                ? 'Borçlu'
                                                : 'Alacaklı',
                                            style: TextStyle(
                                              color: (company.debt - company.receivable) > 0
                                                  ? AppColors.error
                                                  : AppColors.statusCompleted,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 16),

                                      // Notlar
                                      Text(
                                        'Notlar:',
                                        style: TextStyle(
                                          color: AppColors.primaryOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkGray,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          company.notes,
                                          style: TextStyle(
                                            color: AppColors.textGray,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Butonlar
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: AppColors.primaryOrange),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CompanyFormScreen(
                                                    company: company,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: AppColors.error),
                                            onPressed: () =>
                                                _showDeleteDialog(context, company),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
          ),
        ),
      ],
    );
  }

  Widget _buildPromissoryNotesTab() {
    return Column(
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _promissoryNoteSearchQuery = value.toLowerCase();
              });
            },
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Şirket adı veya ürün ile ara...',
              hintStyle: TextStyle(color: AppColors.textGray),
              prefixIcon: Icon(Icons.search, color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Senet Listesi
        Expanded(
          child: StreamBuilder<List<PromissoryNoteModel>>(
            stream: _firestoreService.getAllPromissoryNotes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(color: AppColors.error),
                  ),
                );
              }

              var notes = snapshot.data ?? [];

              // Arama filtresi uygula
              if (_promissoryNoteSearchQuery.isNotEmpty) {
                notes = notes.where((note) {
                  bool matchesCompany = note.companyName.toLowerCase().contains(_promissoryNoteSearchQuery);
                  bool matchesItems = note.items.any((item) => 
                    item.description.toLowerCase().contains(_promissoryNoteSearchQuery)
                  );
                  return matchesCompany || matchesItems;
                }).toList();
              }

              // Ödeme tarihine göre sırala (yaklaşan ödemeler önce)
              notes.sort((a, b) {
                // Önce ödenmemiş taksitlerin en yakın tarihine göre
                final aNextPayment = a.paymentSchedule
                    .where((p) => !p.isPaid)
                    .map((p) => p.dueDate)
                    .fold<DateTime?>(null, (min, date) => min == null || date.isBefore(min) ? date : min);
                final bNextPayment = b.paymentSchedule
                    .where((p) => !p.isPaid)
                    .map((p) => p.dueDate)
                    .fold<DateTime?>(null, (min, date) => min == null || date.isBefore(min) ? date : min);
                
                if (aNextPayment == null && bNextPayment == null) return 0;
                if (aNextPayment == null) return 1;
                if (bNextPayment == null) return -1;
                return aNextPayment.compareTo(bNextPayment);
              });

              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _promissoryNoteSearchQuery.isEmpty
                            ? 'Henüz senet eklenmemiş'
                            : 'Arama sonucu bulunamadı',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final unpaidPayments = note.paymentSchedule.where((p) => !p.isPaid).toList();
                  final paidPayments = note.paymentSchedule.where((p) => p.isPaid).toList();
                  final nextPayment = unpaidPayments.isNotEmpty
                      ? unpaidPayments.map((p) => p.dueDate).reduce((a, b) => a.isBefore(b) ? a : b)
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.mediumGray,
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: nextPayment != null && nextPayment.isBefore(DateTime.now().add(const Duration(days: 7)))
                            ? AppColors.error
                            : nextPayment != null && nextPayment.isBefore(DateTime.now().add(const Duration(days: 30)))
                                ? AppColors.statusWaiting
                                : AppColors.statusCompleted,
                        child: Icon(
                          Icons.receipt_long,
                          color: AppColors.white,
                        ),
                      ),
                      title: Text(
                        note.companyName,
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.items.map((item) => item.description).join(', '),
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nextPayment != null)
                            Text(
                              'Sonraki Ödeme: ${DateFormat('dd.MM.yyyy').format(nextPayment)}',
                              style: TextStyle(
                                color: nextPayment.isBefore(DateTime.now())
                                    ? AppColors.error
                                    : nextPayment.isBefore(DateTime.now().add(const Duration(days: 7)))
                                        ? AppColors.statusWaiting
                                        : AppColors.textGray,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ürün Bilgileri
                              Text(
                                'Ürün Bilgileri',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...note.items.asMap().entries.map((entry) {
                                int index = entry.key;
                                var item = entry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (note.items.length > 1)
                                      Text(
                                        'Ürün ${index + 1}:',
                                        style: TextStyle(
                                          color: AppColors.textGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    _buildInfoRow('Açıklama:', item.description),
                                    _buildInfoRow('Miktar:', '${item.quantity.toStringAsFixed(2)}'),
                                    _buildInfoRow('Birim Fiyat:', '${item.unitPrice.toStringAsFixed(2)} ₺'),
                                    _buildInfoRow('Ara Toplam:', '${item.subtotal.toStringAsFixed(2)} ₺'),
                                    if (index < note.items.length - 1) const Divider(color: AppColors.textGray, height: 16),
                                  ],
                                );
                              }).toList(),
                              const SizedBox(height: 8),
                              _buildInfoRow('Toplam Tutar:', '${note.totalAmount.toStringAsFixed(2)} ₺'),
                              _buildInfoRow('Taksit Sayısı:', '${note.installmentCount}'),
                              _buildInfoRow('Alış Tarihi:', DateFormat('dd.MM.yyyy').format(note.purchaseDate)),
                              _buildInfoRow('İlk Ödeme:', DateFormat('dd.MM.yyyy').format(note.firstPaymentDate)),
                              const Divider(color: AppColors.textGray, height: 24),

                              // Ödeme Planı
                              Text(
                                'Ödeme Planı',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...note.paymentSchedule.map((payment) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: payment.isPaid
                                        ? AppColors.statusCompleted.withOpacity(0.2)
                                        : payment.dueDate.isBefore(DateTime.now())
                                            ? AppColors.error.withOpacity(0.2)
                                            : AppColors.darkGray,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: payment.isPaid
                                          ? AppColors.statusCompleted
                                          : payment.dueDate.isBefore(DateTime.now())
                                              ? AppColors.error
                                              : AppColors.textGray,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${payment.installmentNumber}. Taksit',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('dd.MM.yyyy').format(payment.dueDate),
                                            style: TextStyle(
                                              color: AppColors.textGray,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${payment.amount.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              color: payment.isPaid
                                                  ? AppColors.statusCompleted
                                                  : payment.dueDate.isBefore(DateTime.now())
                                                      ? AppColors.error
                                                      : AppColors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            payment.isPaid
                                                ? Icons.check_circle
                                                : payment.dueDate.isBefore(DateTime.now())
                                                    ? Icons.error
                                                    : Icons.schedule,
                                            color: payment.isPaid
                                                ? AppColors.statusCompleted
                                                : payment.dueDate.isBefore(DateTime.now())
                                                    ? AppColors.error
                                                    : AppColors.textGray,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ödenen:',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${paidPayments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.statusCompleted,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kalan:',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${unpaidPayments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: unpaidPayments.any((p) => p.dueDate.isBefore(DateTime.now()))
                                          ? AppColors.error
                                          : AppColors.statusWaiting,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              // Notlar
                              if (note.notes != null && note.notes!.isNotEmpty) ...[
                                const Divider(color: AppColors.textGray, height: 24),
                                Text(
                                  'Notlar:',
                                  style: TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    note.notes!,
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],

                              // Butonlar
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.primaryOrange),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PromissoryNoteFormScreen(
                                            note: note,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppColors.error),
                                    onPressed: () => _showDeleteNoteDialog(context, note),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textGray),
          ),
          Text(
            value,
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteNoteDialog(BuildContext context, PromissoryNoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Seneti Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            '${note.companyName} adlı şirketten alınan "${note.items.map((item) => item.description).join(', ')}" senetini silmek istediğinizden emin misiniz?',
            style: TextStyle(color: AppColors.textGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Sil',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await _firestoreService.deletePromissoryNote(note.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senet başarıyla silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
