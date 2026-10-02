import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'models/soil_plot.dart';
import 'models/soil_record.dart';
import 'services/esp32_service.dart';
import 'services/measurement_service.dart';
import 'services/plant_service.dart';

import 'login.dart';
import 'profile_screen.dart';

part 'dashboard/lifecycle.dart';
part 'dashboard/data_controller.dart';
part 'dashboard/measurement_controller.dart';
part 'dashboard/dialogs.dart';
part 'dashboard/plant_controller.dart';
part 'dashboard/ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final Esp32Service _esp32Service = Esp32Service();
  final PlantService _plantService = PlantService();
  final MeasurementService _measurementService = MeasurementService();

  Timer? _pollingTimer;
  Timer? _countdownTimer;
  late AnimationController _measuringAnimationController;

  bool isConnectedToESP = false;
  bool isFetching = false;

  int moistureValue = 0;
  double tempValue = 0.0;
  double batteryVolt = 0.0;

  List<SoilPlot> plots = [];
  int selectedPlotIndex = 0;
  bool isLoadingPlants = true;

  bool isMeasuring = false;
  int remainingSeconds = 0;
  int totalDurationSeconds = 120;
  bool isProbeAlertShown = false;

  final List<int> sessionMoisture = [];
  final List<double> sessionTemp = [];

  bool isSyncing = false;
  bool isDarkMode = false;

void _setDarkMode(bool value) {
  setState(() {
    isDarkMode = value;
  });
}

  String profileName = 'Pengguna';
  String profileEmail = '';
  bool isLoadingProfile = true;

  Color get primaryTextColor =>
      isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

  Color get secondaryTextColor =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  Color get panelColor =>
      isDarkMode ? const Color(0xFF111827) : Colors.white;

  Color get panelSecondaryColor =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  /// Jumlah record lokal yang benar-benar belum tersinkronisasi.
  /// Record yang dibaca dari Firebase selalu dibuat dengan isSynced=true.
  int get pendingUploadCount {
    var count = 0;

    for (final plot in plots) {
      for (final record in plot.records) {
        if (!record.isSynced) count++;
      }
    }

    return count;
  }

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _disposeDashboard();
    super.dispose();
  }

  /// Mengunggah seluruh antrean lokal melalui satu jalur penyimpanan:
  /// users/{uid}/plants/{plantId}/measurements.
  Future<void> _uploadPendingDataToServer() async {
    if (isSyncing || pendingUploadCount == 0) return;

    if (mounted) setState(() => isSyncing = true);

    try {
      final pendingBefore = await _getPendingRecords();
      final syncedCount = await _measurementService.syncPendingRecords();

      for (final item in pendingBefore) {
        final plantId = item['plantId'] as String?;
        final timestamp = DateTime.tryParse(
          item['timestamp'] as String? ?? '',
        );
        if (plantId == null || timestamp == null) continue;

        final plotIndex = plots.indexWhere((p) => p.id == plantId);
        if (plotIndex == -1) continue;

        for (final record in plots[plotIndex].records) {
          if (record.timestamp.isAtSameMomentAs(timestamp) &&
              record.avgMoisture ==
                  (item['avgMoisture'] as num?)?.toInt() &&
              record.avgTemp == (item['avgTemp'] as num?)?.toDouble()) {
            record.isSynced = true;
          }
        }
      }

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedCount > 0
                  ? '$syncedCount data berhasil disinkronkan.'
                  : 'Semua data sudah tersinkronisasi.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah data: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildDashboard(context);
  }
}
