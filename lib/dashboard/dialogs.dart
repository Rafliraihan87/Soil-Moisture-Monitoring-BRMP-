part of '../dashboard.dart';

extension _DashboardDialogs on _DashboardScreenState {
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
  
                  // CARD PROFIL PENGGUNA - DINAMIS DARI FIREBASE
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0E7FF),
                        child: isLoadingProfile
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: Color(0xFF4A72EC),
                              ),
                      ),
                      title: Text(
                        profileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        isLoadingProfile
                            ? 'Memuat data akun...'
                            : profileEmail,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
  Icons.chevron_right_rounded,
),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        ).then((_) => _loadUserProfile());
                      },
                    ),
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
}
