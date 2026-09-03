import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  String name;
  final List<SoilRecord> records;

  SoilPlot({required this.name, required this.records});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  // Status Koneksi ESP32
  bool isConnectedToESP = false;
  bool isFetching = false;

  // Nilai Real-time Sensor
  int moistureValue = 0;
  double tempValue = 0.0;
  double batteryVolt = 0.0;

  // Alur Sampling & Pengukuran
  List<SoilPlot> plots = [
    SoilPlot(name: 'Tanah 1', records: []),
  ];
  int selectedPlotIndex = 0;
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
    _fetchSensorData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchSensorData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Polling HTTP ke ESP32 SoftAP
  Future<void> _fetchSensorData() async {
    if (isFetching) return;
    isFetching = true;

    final url = Uri.parse('http://192.168.4.1/data');
    try {
      final response = await http.get(url).timeout(const Duration(milliseconds: 1800));
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

          // Jika sedang dalam sesi pengukuran
          if (isMeasuring) {
            sessionMoisture.add(m);
            sessionTemp.add(t);

            // Deteksi sensor dicabut (kelembapan anjlok ke 0%)
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

  // Pop-up Pilih Durasi Menit Pengukuran
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
                      'Durasi untuk plot: ${plots[selectedPlotIndex].name}',
                      style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
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
                            if (val) setModalState(() => selectedMinutes = mins);
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

  // Mulai Hitung Mundur Sesi Pengukuran
  void _startMeasuringSession(int seconds) {
    setState(() {
      isMeasuring = true;
      remainingSeconds = seconds;
      totalDurationSeconds = seconds;
      sessionMoisture.clear();
      sessionTemp.clear();
      isProbeAlertShown = false;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        _finishAndSaveSession();
      }
    });
  }

  // Selesai & Simpan Data Pengukuran
  void _finishAndSaveSession() {
    _countdownTimer?.cancel();
    setState(() => isMeasuring = false);

    if (sessionMoisture.isNotEmpty && sessionTemp.isNotEmpty) {
      final avgM = (sessionMoisture.reduce((a, b) => a + b) / sessionMoisture.length).round();
      final avgT = double.parse((sessionTemp.reduce((a, b) => a + b) / sessionTemp.length).toStringAsFixed(1));

      final plot = plots[selectedPlotIndex];
      final recordIndex = plot.records.length + 1;

      setState(() {
        plot.records.add(SoilRecord(
          testNumber: recordIndex,
          avgMoisture: avgM,
          avgTemp: avgT,
          timestamp: DateTime.now(),
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengukuran $recordIndex dari "${plot.name}" tersimpan!'),
          backgroundColor: const Color(0xFF00C828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Deteksi Sensor Dicabut
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.sensors_off_rounded, color: Colors.orange, size: 26),
                SizedBox(width: 8),
                Text('Alat Sudah Dicabut!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                child: Text('Tetap di ${plots[selectedPlotIndex].name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finishAndSaveSession();
                  _showPlotManagerSheet();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A72EC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Pindah Tanah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Bottom Sheet untuk Memilih / Menambah Tanah Baru
  void _showPlotManagerSheet() {
    final TextEditingController newPlotCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
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
                    Text(
                      'Pilih atau Buat Tanah',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: plots.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final p = plots[index];
                          final isCurrent = selectedPlotIndex == index;
                          return ListTile(
                            tileColor: isCurrent ? const Color(0xFF4A72EC).withOpacity(0.08) : Colors.grey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isCurrent ? const Color(0xFF4A72EC) : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            leading: Icon(
                              Icons.grass_rounded,
                              color: isCurrent ? const Color(0xFF4A72EC) : secondaryTextColor,
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? const Color(0xFF4A72EC) : primaryTextColor,
                              ),
                            ),
                            subtitle: Text('${p.records.length} data tersimpan'),
                            trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4A72EC)) : null,
                            onTap: () {
                              setState(() => selectedPlotIndex = index);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newPlotCtrl,
                            decoration: InputDecoration(
                              hintText: 'Nama tanah baru (mis: Tanah ${plots.length + 1})',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            final text = newPlotCtrl.text.trim();
                            if (text.isNotEmpty) {
                              setState(() {
                                plots.add(SoilPlot(name: text, records: []));
                                selectedPlotIndex = plots.length - 1;
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          child: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentPlot = plots[selectedPlotIndex];

    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // 1. Background Jeruk (Full Screen)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Image.asset(
                  'assets/bg_orange.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFEAB308),
                  ),
                ),
              ),
            ),

            // 2. Header Atas
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                            shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnectedToESP ? const Color(0xFF00E639) : Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnectedToESP ? 'WiFi Terhubung' : 'WiFi Belum Terhubung',
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
                      onTap: _fetchSensorData,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Curved Bottom Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: screenHeight * 0.78,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner Peringatan jika belum terhubung
                          if (!isConnectedToESP) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.shade600, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.wifi_off_rounded, color: Colors.amber.shade900, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pastikan HP tersambung ke WiFi "CitriSoil_ESP32" untuk membaca data tanah.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Bar Pilihan Tanah
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.grass_rounded, color: Color(0xFF4A72EC), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Target: ${currentPlot.name}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _showPlotManagerSheet,
                                  icon: const Icon(Icons.add_location_alt_rounded, size: 16, color: Color(0xFF4A72EC)),
                                  label: const Text('Ganti / Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A72EC))),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                          ),

                          // Twin Cards: Kelembapan & Suhu
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Kelembapan',
                                  value: isConnectedToESP ? '$moistureValue%' : '--',
                                  status: isConnectedToESP
                                      ? (isMeasuring ? 'Merekam data...' : (moistureValue < 45 ? 'Kering' : 'Optimal'))
                                      : 'Menunggu data',
                                  icon: Icons.water_drop_rounded,
                                  accentColor: const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Suhu Tanah',
                                  value: isConnectedToESP ? '${tempValue.toStringAsFixed(1)}°C' : '--',
                                  status: isConnectedToESP
                                      ? (isMeasuring ? 'Merekam data...' : 'Suhu Terdeteksi')
                                      : 'Menunggu data',
                                  icon: Icons.thermostat_rounded,
                                  accentColor: const Color(0xFFF97316),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // >>> TOMBOL START PENGUKURAN (FOKUS UTAMA DI TENGAH) <<<
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMeasuring
                                    ? [const Color(0xFFEF4444), const Color(0xFFF87171)]
                                    : [const Color(0xFF4A72EC), const Color(0xFF38BDF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: (isMeasuring ? Colors.redAccent : const Color(0xFF4A72EC)).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isMeasuring ? _finishAndSaveSession : _showDurationPickerModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isMeasuring ? Icons.stop_circle_rounded : Icons.play_arrow_rounded,
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
                          const SizedBox(height: 16),

                          // Card Jalur Komunikasi Lokal
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Jalur Komunikasi Lokal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A72EC).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('ESP32 SoftAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4A72EC))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow('SSID Perangkat', 'CitriSoil_ESP32'),
                                const Divider(height: 14),
                                _buildDetailRow('IP Gateway', '192.168.4.1'),
                                const Divider(height: 14),
                                _buildDetailRow('Protokol Data', 'HTTP GET (/data)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Baterai & Status Link
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.battery_charging_full_rounded, color: Color(0xFF10B981), size: 22),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Baterai Node', style: TextStyle(fontSize: 10.5, color: secondaryTextColor)),
                                          Text(
                                            isConnectedToESP ? '${batteryVolt.toStringAsFixed(2)} V' : '-- V',
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryTextColor),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isConnectedToESP ? Icons.router_rounded : Icons.signal_wifi_bad_rounded,
                                        color: isConnectedToESP ? const Color(0xFF4A72EC) : Colors.grey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Status Link', style: TextStyle(fontSize: 10.5, color: secondaryTextColor)),
                                          Text(
                                            isConnectedToESP ? 'Online (Lokal)' : 'Offline',
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryTextColor),
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

                          // Footer Logo
                          Center(
                            child: Image.asset(
                              'assets/logo_kementan.webp',
                              height: 50,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor)),
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
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryTextColor)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor)),
      ],
    );
  }
}