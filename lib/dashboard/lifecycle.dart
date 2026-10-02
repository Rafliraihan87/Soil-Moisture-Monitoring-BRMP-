part of '../dashboard.dart';

extension _DashboardLifecycle on _DashboardScreenState {
  void _initializeDashboard() {
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
