import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

class WeatherService {
  // OpenWeatherMap API key
  static const String _apiKey = '2b990597714c647cb7035ac7d50aa8fa';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _city = 'Denizli';
  static const String _countryCode = 'TR';

  Future<WeatherData?> getWeather() async {
    try {
      // Eğer API key girilmemişse null döndür
      if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
        debugPrint('Hava durumu: API key boş');
        return null;
      }

      final url = Uri.parse(
        '$_baseUrl/weather?q=$_city,$_countryCode&appid=$_apiKey&units=metric&lang=tr',
      );

      debugPrint('Hava durumu API çağrısı başlatılıyor: $_city, $_countryCode');

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Hava durumu: Zaman aşımı (15 saniye)');
          throw TimeoutException('Hava durumu bilgisi alınamadı. İnternet bağlantınızı kontrol edin.');
        },
      );

      debugPrint('Hava durumu API yanıtı: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          // Veri kontrolü
          if (data['main'] == null || data['weather'] == null) {
            debugPrint('Hava durumu: API yanıtında eksik veri');
            return null;
          }

          final main = data['main'] as Map<String, dynamic>;
          final weatherList = data['weather'] as List;
          
          if (weatherList.isEmpty) {
            debugPrint('Hava durumu: Weather listesi boş');
            return null;
          }

          final weather = weatherList.first as Map<String, dynamic>;
          final temp = main['temp'];
          
          if (temp == null) {
            debugPrint('Hava durumu: Sıcaklık bilgisi yok');
            return null;
          }

          debugPrint('Hava durumu başarıyla alındı: ${temp}°C, Durum: ${weather['main']}');
          return WeatherData.fromJson(data);
        } catch (e) {
          debugPrint('Hava durumu: JSON parse hatası: $e');
          debugPrint('Hava durumu: Response body: ${response.body}');
          return null;
        }
      } else {
        // Hata durumunda debug bilgisi
        debugPrint('Hava durumu API hatası: ${response.statusCode}');
        debugPrint('Hava durumu: Response body: ${response.body}');
        
        if (response.statusCode == 401) {
          debugPrint('Hava durumu: API key hatası - Lütfen API key\'inizi kontrol edin');
        } else if (response.statusCode == 404) {
          debugPrint('Hava durumu: Şehir bulunamadı: $_city, $_countryCode');
        } else if (response.statusCode == 429) {
          debugPrint('Hava durumu: API rate limit aşıldı');
        }
        return null;
      }
    } on TimeoutException catch (e) {
      debugPrint('Hava durumu servisi zaman aşımı: $e');
      return null;
    } on http.ClientException catch (e) {
      debugPrint('Hava durumu servisi bağlantı hatası: $e');
      return null;
    } catch (e) {
      // Hata durumunda debug bilgisi
      debugPrint('Hava durumu servisi genel hatası: $e');
      debugPrint('Hata tipi: ${e.runtimeType}');
      return null;
    }
  }
}

class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final String mainCondition;

  WeatherData({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.mainCondition,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      description: weather['description'] as String? ?? '',
      icon: weather['icon'] as String? ?? '01d',
      mainCondition: weather['main'] as String? ?? 'Clear',
    );
  }

  // Hava durumu ikonunu Material Icons'a çevir
  IconData get weatherIcon {
    switch (mainCondition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
      case 'haze':
        return Icons.blur_on;
      default:
        return Icons.wb_cloudy;
    }
  }

  // Hava durumu rengini belirle
  Color get weatherColor {
    switch (mainCondition.toLowerCase()) {
      case 'clear':
        return const Color(0xFFFFD700); // Altın sarısı (güneşli)
      case 'clouds':
        return const Color(0xFFB0BEC5); // Açık gri (bulutlu)
      case 'rain':
      case 'drizzle':
        return const Color(0xFF64B5F6); // Açık mavi (yağmurlu)
      case 'thunderstorm':
        return const Color(0xFF9C27B0); // Mor (fırtınalı)
      case 'snow':
        return const Color(0xFFE1F5FE); // Açık mavi (karlı)
      default:
        return const Color(0xFF90A4AE); // Gri
    }
  }
}
