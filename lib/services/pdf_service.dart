import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/order_model.dart';

class PdfService {
  // Görseli optimize et ve PDF için hazırla
  Future<Uint8List> _optimizeImageForPdf(Uint8List imageBytes) async {
    try {
      if (kIsWeb) {
        // Web'de flutter_image_compress çalışmaz, sadece boyutlandırma yap
        return imageBytes;
      }

      // Görseli sıkıştır
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 1200, // Maksimum yükseklik
        minWidth: 1200, // Maksimum genişlik
        quality: 65, // Kalite %65
        format: CompressFormat.jpeg,
      );

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      debugPrint('Görsel optimizasyon hatası: $e');
      // Hata durumunda orijinal görseli döndür
      return imageBytes;
    }
  }

  // Network'ten görsel yükle ve optimize et
  Future<pw.MemoryImage?> _loadAndOptimizeImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final optimizedBytes = await _optimizeImageForPdf(response.bodyBytes);
        return pw.MemoryImage(optimizedBytes);
      }
    } catch (e) {
      debugPrint('Görsel yükleme hatası: $e');
    }
    return null;
  }

  // Font yükleme - Türkçe karakter desteği için
  // NotoSans veya OpenSans fontunu asset olarak eklemek için: assets/fonts/NotoSans-Regular.ttf
  Future<pw.Font> _loadTurkishFont() async {
    try {
      if (!kIsWeb) {
        // Mobile'da asset'ten font yükleme denemesi
        try {
          // Önce NotoSans-Regular.ttf'yi dene
          final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
          debugPrint('NotoSans fontu başarıyla yüklendi');
          return pw.Font.ttf(fontData);
        } catch (e1) {
          debugPrint('NotoSans fontu yüklenemedi, OpenSans deneniyor: $e1');
          try {
            // NotoSans yoksa OpenSans-Regular.ttf'yi dene
            final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
            debugPrint('OpenSans fontu başarıyla yüklendi');
            return pw.Font.ttf(fontData);
          } catch (e2) {
            debugPrint('OpenSans fontu da yüklenemedi, varsayılan font kullanılacak: $e2');
          }
        }
      } else {
        // Web'de font yükleme (şimdilik desteklenmiyor)
        debugPrint('Web platformunda custom font yükleme desteklenmiyor, varsayılan font kullanılacak');
      }
      // Varsayılan font (Türkçe karakterleri desteklemeyebilir)
      // Not: Helvetica Türkçe karakterleri desteklemez, bu yüzden font dosyası eklenmeli
      return pw.Font.helvetica();
    } catch (e) {
      debugPrint('Font yükleme hatası: $e');
      return pw.Font.helvetica();
    }
  }

  // PDF oluştur ve dosya olarak döndür
  Future<Uint8List> generateOrderPdf(OrderModel order) async {
    try {
      final pdf = pw.Document();
      
      // Font yükleme - Türkçe karakter desteği için
      final font = await _loadTurkishFont();
      
      final dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
      final dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

      // Logo yükleme
      pw.MemoryImage? logoImage;
      if (!kIsWeb) {
        try {
          final logoData = await rootBundle.load('assets/images/logo.png');
          logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
        } catch (e) {
          debugPrint('Logo yüklenemedi: $e');
        }
      }

      // Görselleri yükle ve optimize et
      final photoImage = await _loadAndOptimizeImage(order.photoUrl);
      final drawingImage = await _loadAndOptimizeImage(order.drawingUrl);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ========== HEADER ==========
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Sol üst: Logo
                    if (logoImage != null)
                      pw.Image(
                        logoImage,
                        width: 80,
                        height: 80,
                        fit: pw.BoxFit.contain,
                      )
                    else
                      pw.Container(
                        width: 80,
                        height: 80,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey300,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'LOGO',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                              font: font,
                            ),
                          ),
                        ),
                      ),
                    // Sağ üst: Tarih ve Sipariş No
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Tarih: ${dateTimeFormat.format(order.createdAt)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                            font: font,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Sipariş No: ${order.customOrderNumber}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: font,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // ========== BODY: Müşteri Bilgileri Tablosu ==========
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 1,
                  ),
                  children: [
                    // Başlık satırı
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'MÜŞTERİ BİLGİLERİ',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              font: font,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Müşteri Adı
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Müşteri Adı:',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              font: font,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            order.customerName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              font: font,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Telefon
                    if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Telefon:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              order.customerPhone!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Adres
                    if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Adres:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              order.customerAddress!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // ========== BODY: Sipariş Detayları Tablosu ==========
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 1,
                  ),
                  children: [
                    // Başlık satırı
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'SİPARİŞ DETAYLARI',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              font: font,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Ürün Adı
                    if (order.productName != null && order.productName!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Ürün Adı:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              order.productName!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Renk
                    if (order.productColor != null && order.productColor!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Renk:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              order.productColor!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Detaylar
                    if (order.details.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Detaylar:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              order.details,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Teslim Tarihi
                    if (order.dueDate != null)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Teslim Tarihi:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              dateFormat.format(order.dueDate!),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Fiyat
                    if (order.price != null && order.price! > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Fiyat:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${order.price!.toStringAsFixed(2)} TL ${order.paymentType != null ? '(${order.paymentType})' : ''}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // ========== FOTOĞRAF ==========
                if (photoImage != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FOTOĞRAF',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: font,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Center(
                          child: pw.Container(
                            constraints: const pw.BoxConstraints(
                              maxWidth: 400,
                              maxHeight: 400,
                            ),
                            child: pw.Image(
                              photoImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ========== KROKİ ==========
                if (drawingImage != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'KROKİ',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: font,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Center(
                          child: pw.Container(
                            constraints: const pw.BoxConstraints(
                              maxWidth: 400,
                              maxHeight: 400,
                            ),
                            child: pw.Image(
                              drawingImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ========== FOOTER: İmza Kutucukları ==========
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                pw.SizedBox(height: 20),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    // Teslim Alan
                    pw.Expanded(
                      child: pw.Container(
                        height: 100,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 1,
                            style: pw.BorderStyle.solid,
                          ),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'TESLİM ALAN',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'İmza',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey500,
                                font: font,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    // Teslim Eden
                    pw.Expanded(
                      child: pw.Container(
                        height: 100,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 1,
                            style: pw.BorderStyle.solid,
                          ),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'TESLİM EDEN',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                                font: font,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'İmza',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey500,
                                font: font,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Teşekkür mesajı
                pw.Center(
                  child: pw.Text(
                    'Bizi tercih ettiğiniz için teşekkürler',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                      font: font,
                    ),
                  ),
                ),
              ],
            );
          },
          theme: pw.ThemeData.withFont(base: font),
        ),
      );

      // PDF'i kaydet ve döndür
      final pdfBytes = await pdf.save();
      
      // PDF bytes'ının geçerli olduğunu kontrol et
      if (pdfBytes.isEmpty) {
        throw Exception('PDF oluşturulamadı: Boş PDF bytes');
      }
      
      // PDF başlığını kontrol et (PDF dosyası %PDF ile başlamalı)
      if (pdfBytes.length < 4 || 
          String.fromCharCodes(pdfBytes.take(4)) != '%PDF') {
        throw Exception('PDF oluşturulamadı: Geçersiz PDF formatı');
      }
      
      return pdfBytes;
    } catch (e, stackTrace) {
      debugPrint('PDF oluşturma hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
