import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeasurementService {
  static const String pendingRecordsKey = 'pending_soil_records';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MeasurementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getPendingRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingRecordsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> _savePendingRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingRecordsKey, jsonEncode(records));
  }

  Future<void> savePendingRecord({
    required String plantId,
    required String plantName,
    required int avgMoisture,
    required double avgTemp,
    required DateTime timestamp,
  }) async {
    final pending = await getPendingRecords();

    // Jangan membuat pending duplikat jika proses penyimpanan dipanggil lagi.
    final alreadyPending = pending.any((item) {
      if (item['plantId'] != plantId) return false;
      final existingTimestamp = DateTime.tryParse(
        item['timestamp'] as String? ?? '',
      );
      return existingTimestamp?.isAtSameMomentAs(timestamp) == true;
    });

    if (alreadyPending) return;

    pending.add({
      'plantId': plantId,
      'plantName': plantName,
      'avgMoisture': avgMoisture,
      'avgTemp': avgTemp,
      'timestamp': timestamp.toIso8601String(),
    });

    await _savePendingRecords(pending);
  }

  Future<void> saveMeasurement({
    required String plantId,
    required int moisture,
    required double temperature,
    required DateTime timestamp,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User belum login.');

    final measurements = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('measurements');

    // Cegah satu pengukuran masuk dua kali, terutama saat sinkronisasi
    // pending setelah perangkat sempat kehilangan koneksi.
    final sameTimestamp = await measurements
        .where('timestamp', isEqualTo: Timestamp.fromDate(timestamp))
        .get();

    final duplicate = sameTimestamp.docs.any((doc) {
      final data = doc.data();
      final storedMoisture = (data['moisture'] as num?)?.toInt();
      final storedTemperature = (data['temperature'] as num?)?.toDouble();

      return storedMoisture == moisture &&
          storedTemperature == temperature;
    });

    if (duplicate) return;

    await measurements.add({
      'moisture': moisture,
      'temperature': temperature,
      'timestamp': Timestamp.fromDate(timestamp),
    });
  }

  Future<int> syncPendingRecords() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final pending = await getPendingRecords();
    if (pending.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var syncedCount = 0;

    for (final item in pending) {
      try {
        final plantId = item['plantId'] as String;
        final timestamp = DateTime.tryParse(
              item['timestamp'] as String? ?? '',
            ) ??
            DateTime.now();

        await saveMeasurement(
          plantId: plantId,
          moisture: (item['avgMoisture'] as num?)?.toInt() ?? 0,
          temperature: (item['avgTemp'] as num?)?.toDouble() ?? 0,
          timestamp: timestamp,
        );

        syncedCount++;
      } catch (_) {
        remaining.add(item);
      }
    }

    await _savePendingRecords(remaining);
    return syncedCount;
  }

  Future<void> deletePendingRecordsForPlant(String plantId) async {
    final pending = await getPendingRecords();
    pending.removeWhere((item) => item['plantId'] == plantId);
    await _savePendingRecords(pending);
  }
}
