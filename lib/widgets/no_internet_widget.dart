import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'İnternet Bağlantısı Yok',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lütfen internet bağlantınızı kontrol edin',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
