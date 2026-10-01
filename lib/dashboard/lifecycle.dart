part of '../dashboard.dart';

extension _DashboardLifecycle on _DashboardScreenState {
  void _initializeDashboard() {
    _loadDisplayPreferences();
    _measuringAnimationController = AnimationController(vsync: this);
    _loadPlants();
    _loadUserProfile();
    _fetchSensorData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchSensorData();
      _syncPendingRecords();
    });
  }

  void _disposeDashboard() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _measuringAnimationController.dispose();
    _esp32Service.dispose();
  }
}

extension _DashboardPreferences on _DashboardScreenState {
  Future<void> _loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      isDarkMode = prefs.getBool('citri_dark_mode') ?? false;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    if (mounted) {
      setState(() {
        isDarkMode = value;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('citri_dark_mode', value);
  }
}
