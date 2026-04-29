import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_colors.dart';
import '../services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({bool isRetry = false}) async {
    if (!isRetry) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final weather = await _weatherService.getWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoading = false;
          if (weather != null) {
            _retryCount = 0; // Başarılı olursa retry sayacını sıfırla
          }
        });
      }
      
      // Debug için
      if (weather == null && _retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('Hava durumu bilgisi alınamadı, yeniden deneme $_retryCount/$_maxRetries');
        
        // 2 saniye bekle ve tekrar dene
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _loadWeather(isRetry: true);
        }
      } else if (weather == null) {
        debugPrint('Hava durumu bilgisi alınamadı (tüm denemeler başarısız)');
      }
    } catch (e) {
      debugPrint('Hava durumu yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Hata durumunda da yeniden dene
        if (_retryCount < _maxRetries) {
          _retryCount++;
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            _loadWeather(isRetry: true);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          // Tıklanınca yeniden yükle (her durumda)
          if (!_isLoading) {
            setState(() {
              _retryCount = 0;
            });
            _loadWeather();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.mediumGray,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _weatherData != null
                  ? AppColors.primaryOrange.withOpacity(0.3)
                  : AppColors.textGray.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yükleniyor durumunda
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  ),
                )
              // Hava durumu bilgisi varsa
              else if (_weatherData != null) ...[
                Icon(
                  _weatherData!.weatherIcon,
                  color: _weatherData!.weatherColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_weatherData!.temperature.toStringAsFixed(0)}°C',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
              // Hata durumunda veya veri yoksa
              else ...[
                Tooltip(
                  message: 'Hava durumu alınamadı. Yeniden denemek için tıklayın.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: AppColors.textGray,
                        size: 18,
                      ),
                      if (_retryCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '?',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
