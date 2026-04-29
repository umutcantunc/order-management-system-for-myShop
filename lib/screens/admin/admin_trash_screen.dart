import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/trash_model.dart';
import '../../constants/app_colors.dart';

class AdminTrashScreen extends StatefulWidget {
  const AdminTrashScreen({Key? key}) : super(key: key);

  @override
  State<AdminTrashScreen> createState() => _AdminTrashScreenState();
}

class _AdminTrashScreenState extends State<AdminTrashScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedCollection; // Filtre için seçilen koleksiyon

  // Koleksiyon isimlerini Türkçe'ye çevir
  String _getCollectionDisplayName(String collection) {
    switch (collection) {
      case 'orders':
        return 'Siparişler';
      case 'shifts':
        return 'Mesai Kayıtları';
      case 'transactions':
        return 'İşlemler';
      case 'bonuses':
        return 'Primler';
      case 'salary_payments':
        return 'Maaş Ödemeleri';
      case 'customers':
        return 'Müşteriler';
      case 'companies':
        return 'Şirketler';
      default:
        return collection;
    }
  }

  // Veri tipine göre özet bilgi göster
  String _getDataSummary(TrashModel trash) {
    final data = trash.data;
    final collection = trash.originalCollection;

    switch (collection) {
      case 'orders':
        return 'Sipariş No: ${data['custom_order_number'] ?? data['order_number'] ?? 'N/A'} - Müşteri: ${data['customer_name'] ?? 'N/A'}';
      case 'shifts':
        final dateData = data['date'];
        if (dateData != null && dateData is Timestamp) {
          return 'Tarih: ${DateFormat('dd.MM.yyyy').format(dateData.toDate())}';
        }
        return 'Tarih: N/A';
      case 'transactions':
        return 'Miktar: ${data['amount'] ?? 0} ₺ - Tip: ${data['type'] ?? 'N/A'}';
      case 'bonuses':
        return 'Miktar: ${data['amount'] ?? 0} ₺';
      case 'salary_payments':
        return 'Ödenen: ${data['paid_amount'] ?? 0} ₺';
      case 'customers':
        return 'Müşteri: ${data['name'] ?? 'N/A'}';
      case 'companies':
        return 'Şirket: ${data['name'] ?? 'N/A'}';
      default:
        return 'Veri ID: ${trash.originalId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Çöp Kutusu'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          // Filtre dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrele',
            onSelected: (value) {
              setState(() {
                _selectedCollection = value == 'all' ? null : value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Tümü'),
              ),
              const PopupMenuItem(
                value: 'orders',
                child: Text('Siparişler'),
              ),
              const PopupMenuItem(
                value: 'shifts',
                child: Text('Mesai Kayıtları'),
              ),
              const PopupMenuItem(
                value: 'transactions',
                child: Text('İşlemler'),
              ),
              const PopupMenuItem(
                value: 'bonuses',
                child: Text('Primler'),
              ),
              const PopupMenuItem(
                value: 'salary_payments',
                child: Text('Maaş Ödemeleri'),
              ),
              const PopupMenuItem(
                value: 'customers',
                child: Text('Müşteriler'),
              ),
              const PopupMenuItem(
                value: 'companies',
                child: Text('Şirketler'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<TrashModel>>(
        stream: _selectedCollection == null
            ? _firestoreService.getAllTrash()
            : _firestoreService.getTrashByCollection(_selectedCollection!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hata: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final trashItems = snapshot.data ?? [];

          if (trashItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: AppColors.textGray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Çöp kutusu boş',
                    style: GoogleFonts.poppins(
                      color: AppColors.textGray,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trashItems.length,
            itemBuilder: (context, index) {
              final trash = trashItems[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.mediumGray,
                child: ExpansionTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  title: Text(
                    _getCollectionDisplayName(trash.originalCollection),
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        _getDataSummary(trash),
                        style: GoogleFonts.poppins(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Silinme: ${DateFormat('dd.MM.yyyy HH:mm').format(trash.deletedAt)}',
                        style: GoogleFonts.poppins(
                          color: AppColors.textGray.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      if (trash.description != null && trash.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          trash.description!,
                          style: GoogleFonts.poppins(
                            color: AppColors.textGray,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showRestoreDialog(context, trash),
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('Geri Yükle'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.statusCompleted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _showDeleteDialog(context, trash),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Kalıcı Sil'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
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
    );
  }

  Future<void> _showRestoreDialog(BuildContext context, TrashModel trash) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          'Geri Yükle',
          style: GoogleFonts.poppins(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Bu veriyi geri yüklemek istediğinizden emin misiniz?',
          style: GoogleFonts.poppins(
            color: AppColors.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(
                color: AppColors.textGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Geri Yükle',
              style: GoogleFonts.poppins(
                color: AppColors.statusCompleted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _firestoreService.restoreFromTrash(trash.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Veri başarıyla geri yüklendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Geri yükleme hatası: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, TrashModel trash) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          'Kalıcı Olarak Sil',
          style: GoogleFonts.poppins(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Bu veriyi kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz!',
          style: GoogleFonts.poppins(
            color: AppColors.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(
                color: AppColors.textGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Kalıcı Sil',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _firestoreService.permanentlyDeleteFromTrash(trash.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Veri kalıcı olarak silindi'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
