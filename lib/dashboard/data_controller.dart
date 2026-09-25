part of '../dashboard.dart';

extension _DashboardDataController on _DashboardScreenState {
  Future<List<Map<String, dynamic>>> _getPendingRecords() {
      return _measurementService.getPendingRecords();
    }

  Future<void> _saveRecordLocally({
    required String plantId,
    required String plantName,
    required int avgMoisture,
    required double avgTemp,
    required DateTime timestamp,
  }) async {
    await _measurementService.savePendingRecord(
      plantId: plantId,
      plantName: plantName,
      avgMoisture: avgMoisture,
      avgTemp: avgTemp,
      timestamp: timestamp,
    );
  }

  Future<void> _loadPlants() async {
      try {
        final loaded = await _plantService.getPlants();
  
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
      try {
        final syncedCount = await _measurementService.syncPendingRecords();
  
        if (syncedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$syncedCount data offline berhasil disinkronkan ke database.',
              ),
              backgroundColor: const Color(0xFF00C828),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        // Akan dicoba lagi pada polling berikutnya.
      }
    }

  Future<void> _fetchSensorData() async {
      if (isFetching) return;
      isFetching = true;
  
      try {
        final data = await _esp32Service.fetchSensorData();
  
        if (mounted) {
          setState(() {
            isConnectedToESP = true;
            moistureValue = data.moisture;
            tempValue = data.temperature;
            batteryVolt = data.battery;
          });
  
          if (isMeasuring) {
            sessionMoisture.add(data.moisture);
            sessionTemp.add(data.temperature);
  
            if (data.moisture <= 2 &&
                !isProbeAlertShown &&
                sessionMoisture.length > 3) {
              _handleSensorDetached();
            }
          }
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
  
    // ============================================================
    // FIREBASE - PROFIL PENGGUNA
    // ============================================================

  Future<void> _loadUserProfile() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            profileName = 'Pengguna';
            profileEmail = '';
            isLoadingProfile = false;
          });
        }
        return;
      }
  
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
  
        final data = doc.data();
        final firestoreName = (data?['name'] as String?)?.trim() ?? '';
        final authName = user.displayName?.trim() ?? '';
  
        // Prioritas: nama Firestore -> Firebase Auth -> bagian sebelum @ email.
        final fallbackName = (user.email ?? 'Pengguna').split('@').first.trim();
        final resolvedName = firestoreName.isNotEmpty
            ? firestoreName
            : authName.isNotEmpty
                ? authName
                : (fallbackName.isNotEmpty ? fallbackName : 'Pengguna');
  
        if (!mounted) return;
        setState(() {
          profileName = resolvedName;
          profileEmail = user.email ?? '';
          isLoadingProfile = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          profileName = user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : ((user.email ?? 'Pengguna').split('@').first);
          profileEmail = user.email ?? '';
          isLoadingProfile = false;
        });
      }
    }
}
