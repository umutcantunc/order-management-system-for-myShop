import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../constants/app_colors.dart';

class DrawingScreen extends StatefulWidget {
  final String? existingDrawingUrl;
  final String orderId;

  const DrawingScreen({
    Key? key,
    this.existingDrawingUrl,
    required this.orderId,
  }) : super(key: key);

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.white,
    exportBackgroundColor: AppColors.darkGray,
  );

  bool _isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveDrawing() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir çizim yapın'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final Uint8List? imageBytes = await _controller.toPngBytes();
      if (imageBytes != null) {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        String drawingUrl = await orderProvider.uploadDrawingAndUpdateOrder(
          imageBytes.toList(),
          widget.orderId.isNotEmpty ? widget.orderId : 'temp',
        );

        if (mounted) {
          Navigator.pop(context, drawingUrl);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _clearDrawing() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Kroki Çiz'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          if (_isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveDrawing,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Signature(
                controller: _controller,
                backgroundColor: AppColors.darkGray,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearDrawing,
                    icon: const Icon(Icons.clear),
                    label: const Text('Temizle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(color: AppColors.primaryOrange),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _saveDrawing,
                    icon: const Icon(Icons.save),
                    label: const Text('Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
