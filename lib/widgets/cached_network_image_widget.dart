import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/app_colors.dart';

/// Web ve mobile için optimize edilmiş network image widget
/// Firebase Storage URL'lerini güvenli şekilde gösterir
class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedNetworkImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  }) : super(key: key);

  Future<String> _resolveToHttpUrl(String input) async {
    final url = input.trim();
    if (url.isEmpty) return url;

    // Already a normal network URL
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    // Firebase Storage gs:// URL
    if (url.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(url).getDownloadURL();
    }

    // Likely a Firebase Storage path like "photos/xxx.jpg" or "drawings/xxx.jpg"
    // (or any other bucket-relative path stored in Firestore)
    return FirebaseStorage.instance.ref(url).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    // URL kontrolü
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    return FutureBuilder<String>(
      future: _resolveToHttpUrl(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Image URL resolve error: ${snapshot.error}');
          debugPrint('Original imageUrl: $imageUrl');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: AppColors.mediumGray,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                    strokeWidth: 2,
                  ),
                ),
              );
        }

        final resolvedUrl = snapshot.data?.trim() ?? '';
        if (resolvedUrl.isEmpty) {
          return _buildErrorWidget();
        }

    Widget imageWidget = Image.network(
      resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      // Web için cache kontrolü
      cacheWidth: kIsWeb ? (width != null ? width!.toInt() : null) : null,
      cacheHeight: kIsWeb ? (height != null ? height!.toInt() : null) : null,
      // Loading durumu
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: AppColors.mediumGray,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.primaryOrange,
                  strokeWidth: 2,
                ),
              ),
            );
      },
      // Hata durumu
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load error: $error');
        debugPrint('Image URL: $imageUrl');
        debugPrint('Resolved URL: $resolvedUrl');
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: AppColors.mediumGray,
              child: Icon(
                Icons.broken_image,
                color: AppColors.textGray,
                size: (width != null && height != null)
                    ? (width! < height! ? width! * 0.5 : height! * 0.5)
                    : 48,
              ),
            );
      },
      // Web için frameBuilder - daha iyi loading deneyimi
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );

    // Border radius varsa uygula
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: AppColors.mediumGray,
      child: Icon(
        Icons.broken_image,
        color: AppColors.textGray,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.5 : height! * 0.5)
            : 48,
      ),
    );
  }
}
