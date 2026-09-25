part of '../dashboard.dart';

extension _DashboardUi on _DashboardScreenState {
  Widget _buildDashboard(BuildContext context) {
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
