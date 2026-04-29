import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/cached_network_image_widget.dart';

class OrderImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? heroTag; // Hero animasyonu için tag

  const OrderImageViewerScreen({
    Key? key,
    required this.imageUrl,
    this.title = 'Resim',
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = CachedNetworkImageWidget(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            Text(
              'Resim yüklenemedi',
              style: GoogleFonts.poppins(
                color: AppColors.textGray,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: ${imageUrl.length > 50 ? "${imageUrl.substring(0, 50)}..." : imageUrl}',
              style: GoogleFonts.poppins(
                color: AppColors.textGray,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: heroTag != null
              ? Hero(
                  tag: heroTag!,
                  child: imageWidget,
                )
              : imageWidget,
        ),
      ),
    );
  }
}
