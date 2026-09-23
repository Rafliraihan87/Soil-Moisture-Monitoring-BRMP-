import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'login.dart';
import 'profile_screen.dart';

class SoilRecord {
  final int testNumber;
  final int avgMoisture;
  final double avgTemp;
  final DateTime timestamp;

  SoilRecord({
    required this.testNumber,
    required this.avgMoisture,
    required this.avgTemp,
    required this.timestamp,
  });
}

class SoilPlot {
  final String id;
  String name;
  String? imageData;
  final List<SoilRecord> records;

  SoilPlot({
    required this.id,
    required this.name,
    this.imageData,
    required this.records,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final http.Client _client = http.Client();
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  late AnimationController _measuringAnimationController;

  // Status Koneksi ESP32
  bool isConnectedToESP = false;
  bool isFetching = false;

  // Nilai Real-time Sensor
  int moistureValue = 0;
  double tempValue = 0.0;
  double batteryVolt = 0.0;

  // Alur Sampling & Pengukuran
  List<SoilPlot> plots = [];
  int selectedPlotIndex = 0;
  bool isLoadingPlants = true;

  static const String _pendingRecordsKey = 'pending_soil_records';

  bool isMeasuring = false;
  int remainingSeconds = 0;
  int totalDurationSeconds = 120;
  bool isProbeAlertShown = false;

  final List<int> sessionMoisture = [];
  final List<double> sessionTemp = [];

  final Color primaryTextColor = const Color(0xFF1E293B);
  final Color secondaryTextColor = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _measuringAnimationController = AnimationController(vsync: this);
    _loadPlants();
    _fetchSensorData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchSensorData();
      _syncPendingRecords();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _measuringAnimationController.dispose();
    _client.close();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _plantsCollection {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User belum login.');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants');
  }

  Future<List<Map<String, dynamic>>> _getPendingRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingRecordsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> _savePendingRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRecordsKey, jsonEncode(records));
  }

  Future<void> _saveRecordLocally({
    required String plantId,
    required String plantName,
    required int avgMoisture,
    required double avgTemp,
    required DateTime timestamp,
  }) async {
    final pending = await _getPendingRecords();
    pending.add({
      'plantId': plantId,
      'plantName': plantName,
      'avgMoisture': avgMoisture,
      'avgTemp': avgTemp,
      'timestamp': timestamp.toIso8601String(),
    });
    await _savePendingRecords(pending);
  }

  Future<void> _loadPlants() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await _plantsCollection
          .orderBy('createdAt')
          .get();

      final loaded = <SoilPlot>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final records = <SoilRecord>[];

        try {
          final measurementSnapshot = await doc.reference
              .collection('measurements')
              .orderBy('timestamp', descending: false)
              .get();

          for (var i = 0; i < measurementSnapshot.docs.length; i++) {
            final measurement = measurementSnapshot.docs[i].data();
            final ts = measurement['timestamp'];
            DateTime timestamp;

            if (ts is Timestamp) {
              timestamp = ts.toDate();
            } else if (ts is String) {
              timestamp = DateTime.tryParse(ts) ?? DateTime.now();
            } else {
              timestamp = DateTime.now();
            }

            records.add(
              SoilRecord(
                testNumber: i + 1,
                avgMoisture: (measurement['moisture'] as num?)?.toInt() ?? 0,
                avgTemp: (measurement['temperature'] as num?)?.toDouble() ?? 0,
                timestamp: timestamp,
              ),
            );
          }
        } catch (_) {
          // Riwayat tetap kosong jika pembacaan measurement gagal.
        }

        loaded.add(
          SoilPlot(
            id: doc.id,
            name: (data['name'] as String?) ?? 'Tanah',
            imageData: data['imageData'] as String?,
            records: records,
          ),
        );
      }


      if (!mounted) return;
      setState(() {
        plots = loaded;
        selectedPlotIndex = 0;
        isLoadingPlants = false;
      });

      await _applyPendingRecordsToLocalPlots();
      await _syncPendingRecords();
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingPlants = false);
    }
  }

  Future<void> _applyPendingRecordsToLocalPlots() async {
    final pending = await _getPendingRecords();
    if (pending.isEmpty || !mounted) return;

    for (final item in pending) {
      final plantId = item['plantId'] as String?;
      final plotIndex = plots.indexWhere((p) => p.id == plantId);
      if (plotIndex == -1) continue;

      final plot = plots[plotIndex];
      final timestamp = DateTime.tryParse(
            item['timestamp'] as String? ?? '',
          ) ??
          DateTime.now();

      final alreadyExists = plot.records.any(
        (record) => record.timestamp.isAtSameMomentAs(timestamp),
      );

      if (!alreadyExists) {
        plot.records.add(
          SoilRecord(
            testNumber: plot.records.length + 1,
            avgMoisture: (item['avgMoisture'] as num?)?.toInt() ?? 0,
            avgTemp: (item['avgTemp'] as num?)?.toDouble() ?? 0,
            timestamp: timestamp,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _syncPendingRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pending = await _getPendingRecords();
    if (pending.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    var syncedCount = 0;

    for (final item in pending) {
      try {
        final plantId = item['plantId'] as String;
        final timestamp = DateTime.tryParse(
              item['timestamp'] as String? ?? '',
            ) ??
            DateTime.now();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plants')
            .doc(plantId)
            .collection('measurements')
            .add({
          'moisture': (item['avgMoisture'] as num?)?.toInt() ?? 0,
          'temperature': (item['avgTemp'] as num?)?.toDouble() ?? 0,
          'timestamp': Timestamp.fromDate(timestamp),
        });

        syncedCount++;
      } catch (_) {
        remaining.add(item);
      }
    }

    await _savePendingRecords(remaining);

    if (syncedCount > 0 && remaining.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$syncedCount data offline berhasil disinkronkan ke database.'),
          backgroundColor: const Color(0xFF00C828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showOfflineSavedAlert() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data Belum Tersimpan ke Database',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Koneksi ke database tidak tersedia. Data pengukuran sudah disimpan sementara di perangkat dan akan otomatis dikirim ketika koneksi kembali.',
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A72EC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Polling HTTP ke ESP32 SoftAP
  Future<void> _fetchSensorData() async {
    if (isFetching) return;
    isFetching = true;

    final url = Uri.parse('http://192.168.4.1/data');
    try {
      final response = await _client
          .get(url, headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 1800));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final int m = (data['kelembapan'] as num).toInt();
          final double t = (data['suhu'] as num).toDouble();
          final double b = (data['baterai'] as num).toDouble();

          setState(() {
            isConnectedToESP = true;
            moistureValue = m;
            tempValue = t;
            batteryVolt = b;
          });

          if (isMeasuring) {
            sessionMoisture.add(m);
            sessionTemp.add(t);

            if (m <= 2 && !isProbeAlertShown && sessionMoisture.length > 3) {
              _handleSensorDetached();
            }
          }
        }
      } else {
        _setDisconnected();
      }
    } catch (_) {
      _setDisconnected();
    } finally {
      isFetching = false;
    }
  }

  void _setDisconnected() {
    if (mounted && isConnectedToESP) {
      setState(() => isConnectedToESP = false);
    }
  }

  // Modal Setting & Profil Bottom Sheet
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Pengaturan & Pengguna',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),

                // CARD PROFIL PENGGUNA
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.person_rounded, color: Color(0xFF4A72EC)),
                  ),
                  title: const Text(
                    'Profil Pengguna',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Petani Jeruk (petani@citrisoil.com)',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(),

                // INFO HARDWARE
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.memory_rounded, color: Color(0xFF64748B)),
                  ),
                  title: const Text(
                    'Informasi Perangkat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: const Text(
                    'CitriSoil Handheld (ESP32 FireBeetle)',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),

                const Divider(height: 20),

                // TOMBOL LOGOUT
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutConfirmDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Keluar (Logout)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog Konfirmasi Logout
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text(
                  'Konfirmasi Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi CitriSoil Monitor?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _pollingTimer?.cancel();
                  _countdownTimer?.cancel();
                  await FirebaseAuth.instance.signOut();

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Keluar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal Detail Statistik & Riwayat
  void _showMetricDetailModal(bool isMoisture) {
    final currentPlot = plots[selectedPlotIndex];
    final title = isMoisture ? 'Kelembapan Tanah' : 'Suhu Tanah';
    final unit = isMoisture ? '% RH' : '°C';
    final accentColor = isMoisture
        ? const Color(0xFF38BDF8)
        : const Color(0xFFF97316);

    double avgValue = 0;
    num minValue = 0;
    num maxValue = 0;

    if (currentPlot.records.isNotEmpty) {
      final values = currentPlot.records
          .map((r) => isMoisture ? r.avgMoisture : r.avgTemp)
          .toList();
      avgValue = values.reduce((a, b) => a + b) / values.length;
      minValue = values.reduce((a, b) => a < b ? a : b);
      maxValue = values.reduce((a, b) => a > b ? a : b);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.68,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      isMoisture
                          ? Icons.water_drop_rounded
                          : Icons.thermostat_rounded,
                      color: accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Statistik $title',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Target: ${currentPlot.name}',
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
                const SizedBox(height: 16),

                if (currentPlot.records.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatSubItem(
                          'Rata-rata',
                          '${avgValue.toStringAsFixed(1)}$unit',
                          primaryTextColor,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        _buildStatSubItem(
                          'Terendah',
                          '$minValue$unit',
                          Colors.blueGrey,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        _buildStatSubItem(
                          'Tertinggi',
                          '$maxValue$unit',
                          Colors.deepOrange,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),
                Text(
                  'Riwayat Tiap Pengukuran',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: currentPlot.records.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada data pengukuran.',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        )
                      : ListView.separated(
                          itemCount: currentPlot.records.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final rec = currentPlot.records[index];
                            final val = isMoisture
                                ? '${rec.avgMoisture}% RH'
                                : '${rec.avgTemp}°C';
                            final dateStr =
                                "${rec.timestamp.day}/${rec.timestamp.month}/${rec.timestamp.year} ${rec.timestamp.hour.toString().padLeft(2, '0')}:${rec.timestamp.minute.toString().padLeft(2, '0')}";

                            return ListTile(
                              tileColor: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: accentColor.withOpacity(0.2),
                                child: Text(
                                  '${rec.testNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Pengukuran ${rec.testNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                dateStr,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                val,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatSubItem(String label, String val, Color valColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // POP-UP PERINGATAN WIFI BELUM TERHUBUNG
  // ============================================================

  void _showWifiRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'WiFi Belum Terhubung',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          content: const Text(
            'Harap terhubung ke WiFi perangkat '
            '"CitriSoil_ESP32" terlebih dahulu sebelum '
            'memulai pengukuran.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),

          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A72EC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Modal Durasi Pengukuran
  void _showDurationPickerModal() {
    int selectedMinutes = 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Pilih Durasi Pengukuran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plot sasaran: ${plots[selectedPlotIndex].name}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [1, 2, 3, 5].map((mins) {
                        final isSel = selectedMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins Menit'),
                          selected: isSel,
                          selectedColor: const Color(0xFF4A72EC),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : primaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val)
                              setModalState(() => selectedMinutes = mins);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _startMeasuringSession(selectedMinutes * 60);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A72EC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Mulai Sekarang',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startMeasuringSession(int seconds) {
    _countdownTimer?.cancel();
    _measuringAnimationController.stop();
    _measuringAnimationController.reset();

    _measuringAnimationController.duration = Duration(seconds: seconds);

    setState(() {
      isMeasuring = true;
      remainingSeconds = seconds;
      totalDurationSeconds = seconds;

      sessionMoisture.clear();
      sessionTemp.clear();
      isProbeAlertShown = false;
    });

    _measuringAnimationController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        _measuringAnimationController.stop();
        _finishAndSaveSession();
      }
    });
  }

  Future<void> _finishAndSaveSession() async {
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() => isMeasuring = false);
    }

    if (sessionMoisture.isEmpty || sessionTemp.isEmpty || plots.isEmpty) {
      return;
    }

    final avgM =
        (sessionMoisture.reduce((a, b) => a + b) / sessionMoisture.length)
            .round();
    final avgT = double.parse(
      (sessionTemp.reduce((a, b) => a + b) / sessionTemp.length)
          .toStringAsFixed(1),
    );

    final plot = plots[selectedPlotIndex];
    final recordIndex = plot.records.length + 1;
    final timestamp = DateTime.now();

    if (mounted) {
      setState(() {
        plot.records.add(
          SoilRecord(
            testNumber: recordIndex,
            avgMoisture: avgM,
            avgTemp: avgT,
            timestamp: timestamp,
          ),
        );
      });
    }

    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user == null) {
        throw StateError('User belum login.');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .doc(plot.id)
          .collection('measurements')
          .add({
        'moisture': avgM,
        'temperature': avgT,
        'timestamp': Timestamp.fromDate(timestamp),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengukuran $recordIndex dari "${plot.name}" tersimpan ke database.',
            ),
            backgroundColor: const Color(0xFF00C828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      await _saveRecordLocally(
        plantId: plot.id,
        plantName: plot.name,
        avgMoisture: avgM,
        avgTemp: avgT,
        timestamp: timestamp,
      );

      _showOfflineSavedAlert();
    }
  }

  void _handleSensorDetached() {
    isProbeAlertShown = true;
    _countdownTimer?.cancel();
    setState(() => isMeasuring = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.sensors_off_rounded, color: Colors.orange, size: 26),
                SizedBox(width: 8),
                Text(
                  'Alat Sudah Dicabut!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: Text(
              'Sensor kelembapan terdeteksi 0%. Pilih untuk tetap di ${plots[selectedPlotIndex].name} atau berpindah tanah.',
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finishAndSaveSession();
                },
                child: Text(
                  'Tetap di ${plots[selectedPlotIndex].name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finishAndSaveSession();
                  _showPlotManagerSheet();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A72EC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pindah Tanah',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog Pemilih Sumber Gambar
  Future<String?> _pickImageBase64() async {
    ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('Lampirkan Foto Tumbuhan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.camera_alt_rounded, color: Color(0xFF4A72EC))),
                  title: const Text('Ambil Foto (Kamera)', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.photo_library_rounded, color: Color(0xFF4A72EC))),
                  title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 65,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _editPlant(SoilPlot plot) async {
    String newName = plot.name;
    String? newImageData = plot.imageData;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Tanaman'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickImageBase64();
                      if (picked != null) {
                        setDialogState(() => newImageData = picked);
                      }
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF4A72EC).withOpacity(0.25)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: newImageData != null
                          ? Image.memory(base64Decode(newImageData!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 36))
                          : const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4A72EC), size: 34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    newImageData == null ? 'Tambah foto tanaman' : 'Ketuk foto untuk mengganti',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: plot.name,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => newName = value,
                    decoration: const InputDecoration(labelText: 'Nama tanaman', hintText: 'Contoh: Jeruk 1'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
                ElevatedButton(onPressed: () { if (newName.trim().isNotEmpty) Navigator.pop(dialogContext, true); }, child: const Text('Simpan')),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final name = newName.trim();
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user == null) throw StateError('User belum login.');

      final docRef = _plantsCollection.doc(plot.id);
      await docRef.update({'name': name, 'imageData': newImageData});

      if (!mounted) return;
      setState(() {
        plot.name = name;
        plot.imageData = newImageData;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanaman berhasil diperbarui.'), behavior: SnackBarBehavior.floating));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah tanaman: ${e.code}'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah tanaman: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deletePlant(SoilPlot plot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Tanaman?'),
          content: Text(
            'Tanaman "${plot.name}" beserta seluruh riwayat pengukurannya akan dihapus dari database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user == null) {
        throw StateError('User belum login.');
      }

      final plantRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .doc(plot.id);

      final plantSnapshot = await plantRef.get();
      if (!plantSnapshot.exists) {
        throw StateError('Data tanaman tidak ditemukan di database.');
      }

      // Firestore tidak otomatis menghapus subcollection ketika parent
      // dihapus. Hapus measurements dalam beberapa batch agar tetap aman
      // meskipun jumlah riwayat pengukuran banyak.
      final measurementsSnapshot =
          await plantRef.collection('measurements').get();
      final measurementDocs = measurementsSnapshot.docs;

      for (var start = 0; start < measurementDocs.length; start += 450) {
        final end = (start + 450 < measurementDocs.length)
            ? start + 450
            : measurementDocs.length;

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in measurementDocs.sublist(start, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Parent dihapus setelah seluruh measurements selesai dihapus.
      await plantRef.delete();

      // Data lokal yang masih menunggu sinkronisasi tidak boleh ikut kembali
      // menghidupkan data tanaman yang sudah dihapus.
      try {
        final pending = await _getPendingRecords();
        pending.removeWhere((item) => item['plantId'] == plot.id);
        await _savePendingRecords(pending);
      } catch (_) {
        // Penghapusan Firestore tetap dianggap berhasil meskipun pembersihan
        // cache lokal gagal.
      }

      if (!mounted) return;
      setState(() {
        final deletedIndex = plots.indexOf(plot);
        plots.remove(plot);

        if (plots.isEmpty) {
          selectedPlotIndex = 0;
        } else if (selectedPlotIndex > deletedIndex) {
          selectedPlotIndex--;
        } else if (selectedPlotIndex >= plots.length) {
          selectedPlotIndex = plots.length - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanaman berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus tanaman: ${e.code}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus tanaman: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Bottom Sheet Memilih / Menambah Tanaman
  void _showPlotManagerSheet() {
    String newPlotName = '';
    String? newPlotImage;
    bool isAddingPlant = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: keyboardBottom),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pilih Tanaman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.30,
                        child: isLoadingPlants
                            ? const Center(child: CircularProgressIndicator())
                            : plots.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.eco_outlined,
                                          size: 46,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Belum ada tanaman',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tambahkan tanaman untuk mulai mengukur.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                itemCount: plots.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final p = plots[index];
                                  final isCurrent = selectedPlotIndex == index;

                                  return Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      tileColor: isCurrent
                                          ? const Color(0xFF4A72EC).withOpacity(0.08)
                                          : Colors.grey.shade50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: isCurrent
                                              ? const Color(0xFF4A72EC)
                                              : Colors.transparent,
                                          width: 1.2,
                                        ),
                                      ),
                                      leading: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: const Color(0xFF4A72EC).withOpacity(0.1),
                                        ),
                                        child: p.imageData != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.memory(
                                                  base64Decode(p.imageData!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: Color(0xFF4A72EC)),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.eco_rounded,
                                                color: Color(0xFF4A72EC),
                                              ),
                                      ),
                                      title: Text(
                                        p.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? const Color(0xFF4A72EC)
                                              : primaryTextColor,
                                        ),
                                      ),
                                      subtitle: Text('${p.records.length} data tersimpan'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrent)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF4A72EC),
                                            ),
                                          PopupMenuButton<String>(
                                            tooltip: 'Kelola tanaman',
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editPlant(p);
                                              } else if (value == 'delete') {
                                                _deletePlant(p);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_rounded, size: 19),
                                                    SizedBox(width: 10),
                                                    Text('Edit nama'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                                                    SizedBox(width: 10),
                                                    Text('Hapus'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        setState(() => selectedPlotIndex = index);
                                        Navigator.pop(sheetContext);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (imageContext, setImageState) {
                          return Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final picked = await _pickImageBase64();
                                  if (picked != null) {
                                    newPlotImage = picked;
                                    setImageState(() {});
                                  }
                                },
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: newPlotImage != null
                                      ? Image.memory(base64Decode(newPlotImage!), fit: BoxFit.cover)
                                      : const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4A72EC)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  newPlotImage == null ? 'Tambah foto tanaman (opsional)' : 'Foto tanaman dipilih',
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => newPlotName = value,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Nama tanaman (mis: Jeruk ${plots.length + 1})',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isAddingPlant
                                ? null
                                : () async {
                                    final text = newPlotName.trim();
                                    if (text.isEmpty) return;

                                    setSheetState(() => isAddingPlant = true);

                                    try {
                                      final doc = await _plantsCollection.add({
                                        'name': text,
                                        'imageData': newPlotImage,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      if (!mounted) return;

                                      setState(() {
                                        plots.add(
                                          SoilPlot(
                                            id: doc.id,
                                            name: text,
                                            imageData: newPlotImage,
                                            records: [],
                                          ),
                                        );
                                        selectedPlotIndex = plots.length - 1;
                                      });

                                      if (Navigator.canPop(sheetContext)) {
                                        Navigator.pop(sheetContext);
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        setSheetState(() => isAddingPlant = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Gagal menambahkan tanah ke database.'),
                                            backgroundColor: Colors.redAccent,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isAddingPlant
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Tambah',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoadingPlants) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Dashboard tetap tampil walaupun belum ada tanaman.
    // Bagian sensor/pengukuran hanya ditampilkan jika sudah ada target.
    final bool hasPlants = plots.isNotEmpty;

    if (hasPlants && selectedPlotIndex >= plots.length) {
      selectedPlotIndex = 0;
    }

    final SoilPlot currentPlot = hasPlants
        ? plots[selectedPlotIndex]
        : SoilPlot(
            id: 'no-plant',
            name: 'Belum ada tanaman',
            imageData: null,
            records: [],
          );

    final bool hasImage = currentPlot.imageData != null;

    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // Background mengikuti foto tanaman yang sedang dipilih.
            // Jika tanaman belum memiliki foto, gunakan background default.
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: hasImage
                        ? Image.memory(
                            base64Decode(currentPlot.imageData!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/bg_orange.png',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/bg_orange.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: const Color(0xFFEAB308)),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.22),
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CitriSoil Monitor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnectedToESP
                                    ? const Color(0xFF00E639)
                                    : Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnectedToESP
                                  ? 'WiFi Terhubung'
                                  : 'WiFi Belum Terhubung',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _showSettingsModal,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Color(0xFF1E293B),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            DraggableScrollableSheet(
              // Panel bisa turun sehingga foto header terlihat lebih banyak,
              // dan bisa naik sampai menutup seluruh header.
              initialChildSize: 0.78,
              minChildSize: 0.55,
              maxChildSize: 1.0,
              snap: false,
              expand: true,
              shouldCloseOnMinExtent: false,
              builder: (context, scrollController) {
                return SizedBox.expand(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(42),
                      topRight: Radius.circular(42),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(42),
                      topRight: Radius.circular(42),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: ListView(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            if (hasPlants && !isConnectedToESP) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.amber.shade600,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.amber.shade900,
                                    size: 24,
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Text(
                                      'Pastikan HP tersambung ke WiFi "CitriSoil_ESP32" untuk membaca data tanah.',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // BAR TARGET TANAH
                          Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  if (hasImage) ...[
                                    Positioned.fill(
                                      child:
                                          Image.memory(
                                              base64Decode(currentPlot.imageData!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                            ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withOpacity(0.70),
                                              Colors.black.withOpacity(0.35),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.eco_rounded,
                                              color: hasImage
                                                  ? Colors.white
                                                  : const Color(0xFF4A72EC),
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Target: ${currentPlot.name}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: hasImage
                                                    ? Colors.white
                                                    : primaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton.icon(
                                          onPressed: _showPlotManagerSheet,
                                          icon: Icon(
                                            Icons.add_location_alt_rounded,
                                            size: 16,
                                            color: hasImage
                                                ? Colors.white
                                                : const Color(0xFF4A72EC),
                                          ),
                                          label: Text(
                                            hasPlants ? 'Ganti / Tambah' : 'Tambah Tanaman',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: hasImage
                                                  ? Colors.white
                                                  : const Color(0xFF4A72EC),
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (hasPlants) ...[
                            // Twin Cards (Bisa Di-klik untuk Membuka Riwayat Khusus)
                            Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Kelembapan',
                                  value: isConnectedToESP
                                      ? '$moistureValue%'
                                      : '--',
                                  status: isConnectedToESP
                                      ? (isMeasuring
                                            ? 'Merekam data...'
                                            : (moistureValue < 45
                                                  ? 'Kering'
                                                  : 'Optimal'))
                                      : 'Menunggu data',
                                  icon: Icons.water_drop_rounded,
                                  accentColor: const Color(0xFF38BDF8),
                                  onTap: () => _showMetricDetailModal(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Suhu Tanah',
                                  value: isConnectedToESP
                                      ? '${tempValue.toStringAsFixed(1)}°C'
                                      : '--',
                                  status: isConnectedToESP
                                      ? (isMeasuring
                                            ? 'Merekam data...'
                                            : 'Suhu Terdeteksi')
                                      : 'Menunggu data',
                                  icon: Icons.thermostat_rounded,
                                  accentColor: const Color(0xFFF97316),
                                  onTap: () => _showMetricDetailModal(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // TOMBOL START / STOP PENGUKURAN WITH PROGRESS
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isMeasuring
                                    ? const Color(0xFFF87171).withOpacity(0.35)
                                    : const Color(0xFF4A72EC),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isMeasuring
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF4A72EC))
                                            .withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  if (isMeasuring)
                                    AnimatedBuilder(
                                      animation: _measuringAnimationController,
                                      builder: (context, child) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor:
                                                _measuringAnimationController
                                                    .value,
                                            heightFactor: 1.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isMeasuring
                                          ? _finishAndSaveSession
                                          : () {
                                              if (!isConnectedToESP) {
                                                _showWifiRequiredDialog();
                                              } else {
                                                _showDurationPickerModal();
                                              }
                                            },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isMeasuring
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isMeasuring
                                                  ? 'Berhenti (${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')})'
                                                  : 'Mulai Pengukuran (${currentPlot.name})',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          ],


                          // Jalur Komunikasi
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Jalur Komunikasi Lokal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A72EC)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'ESP32 SoftAP',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4A72EC),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'SSID Perangkat',
                                  'CitriSoil_ESP32',
                                ),
                                const Divider(height: 14),
                                _buildDetailRow('IP Gateway', '192.168.4.1'),
                                const Divider(height: 14),
                                _buildDetailRow(
                                  'Protokol Data',
                                  'HTTP GET (/data)',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Baterai & Link
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.battery_charging_full_rounded,
                                        color: Color(0xFF10B981),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Baterai Node',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            isConnectedToESP
                                                ? '${batteryVolt.toStringAsFixed(2)} V'
                                                : '-- V',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isConnectedToESP
                                            ? Icons.router_rounded
                                            : Icons.signal_wifi_bad_rounded,
                                        color: isConnectedToESP
                                            ? const Color(0xFF4A72EC)
                                            : Colors.grey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Status Link',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            isConnectedToESP
                                                ? 'Online (Lokal)'
                                                : 'Offline',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Logo Footer
                          Center(
                            child: Image.asset(
                              'assets/logo_kementan.webp',
                              height: 50,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.agriculture_rounded,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String status,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: accentColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }
}
