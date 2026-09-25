import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';

class Esp32Service {
  static const String baseUrl = 'http://192.168.4.1';
  static const Duration timeout = Duration(milliseconds: 1800);

  final http.Client _client;

  Esp32Service({http.Client? client}) : _client = client ?? http.Client();

  Future<SensorData> fetchSensorData() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/data'),
          headers: {'Connection': 'close'},
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('ESP32 HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    return SensorData(
      moisture: (data['kelembapan'] as num).toInt(),
      temperature: (data['suhu'] as num).toDouble(),
      battery: (data['baterai'] as num).toDouble(),
    );
  }

  void dispose() {
    _client.close();
  }
}
