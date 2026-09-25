part of '../dashboard.dart';

extension _DashboardMeasurementController on _DashboardScreenState {
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
  
        await _measurementService.saveMeasurement(
          plantId: plot.id,
          moisture: avgM,
          temperature: avgT,
          timestamp: timestamp,
        );
  
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
}
