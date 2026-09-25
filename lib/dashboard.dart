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

  bool isMeasuring = false;
  int remainingSeconds = 0;
  int totalDurationSeconds = 120;
  bool isProbeAlertShown = false;

  final List<int> sessionMoisture = [];
  final List<double> sessionTemp = [];

  final Color primaryTextColor = const Color(0xFF1E293B);
  final Color secondaryTextColor = const Color(0xFF64748B);

  // Data akun pengguna
  String profileName = 'Pengguna';
  String profileEmail = '';
  bool isLoadingProfile = true;



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

  @override
  Widget build(BuildContext context) {
    return _buildDashboard(context);
  }
}
