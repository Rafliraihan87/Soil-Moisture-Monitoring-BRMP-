import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DashboardScreen(),
  ));
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isPowerOn = true;
  String selectedNode = 'Node 1 (Jeruk Nipis)';

  final List<String> nodeList = [
    'Node 1 (Jeruk Nipis)',
    'Node 2 (Jeruk Manis)',
    'Node 3 (Jeruk Keprok)',
    'Node 4 (Jeruk Siam)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
  fit: StackFit.expand,
  children: [
    // Background blur
    ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 1.8,
        sigmaY: 8,
      ),
      child: Image.asset(
        'assets/bg_orange.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.orange.shade300,
        ),
      ),
    ),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Instansi di Kiri Atas
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.yellow.shade600,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo_kementan.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.eco, color: Colors.green, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hero Card: Status Kebun & Mini Chart
                  _buildHeroCard(),
                  const SizedBox(height: 12),

                  // Baris 3 Kartu (Power, Kelembapan, Suhu)
                  Row(
                    children: [
                      // Card 1: Power Pompa
                      Expanded(child: _buildPowerCard()),
                      const SizedBox(width: 8),
                      // Card 2: Kelembapan
                      Expanded(child: _buildHumidityCard()),
                      const SizedBox(width: 8),
                      // Card 3: Suhu
                      Expanded(child: _buildTemperatureCard()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Baris 2 Kartu (Baterai & Koneksi)
                  Row(
                    children: [
                      // Card Baterai
                      Expanded(child: _buildBatteryCard()),
                      const SizedBox(width: 12),
                      // Card Koneksi
                      Expanded(child: _buildConnectionCard()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bottom Selector: Dropdown Pilih Node
                  _buildNodeSelector(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget: Glass Container Helper
  Widget _buildGlassContainer({
    required Widget child,
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    Color? customColor,
    Border? customBorder,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: customColor ?? Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: customBorder ??
                Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  // 1. Hero Card (Status Kebun & Sparkline Chart)
  Widget _buildHeroCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS KEBUN: OPTIMAL (BLOK A-1)',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.3,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Tanah: 68% | Udara: 26.5°C',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          // Area Grafik Sparkline CustomPainter
          SizedBox(
            height: 70,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklineChartPainter(),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tanah: 68% | Udara: 26.5°C',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              Text(
                'Update: 1 Menit yang lalu',
                style: TextStyle(fontSize: 9.5, color: Colors.black54),
              ),
            ],
          )
        ],
      ),
    );
  }

  // 2. Power / Pompa Card
  Widget _buildPowerCard() {
    return GestureDetector(
      onTap: () => setState(() => isPowerOn = !isPowerOn),
      child: _buildGlassContainer(
        customColor: isPowerOn
            ? const Color(0xFF00E639).withOpacity(0.85)
            : Colors.grey.shade400.withOpacity(0.7),
        child: SizedBox(
          height: 155,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Power',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPowerOn ? Colors.black87 : Colors.black54,
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                  boxShadow: isPowerOn
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 3,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 28,
                  color: isPowerOn ? const Color(0xFF00C828) : Colors.grey,
                ),
              ),
              Text(
                isPowerOn ? 'Pompa Aktif\n(MANUAL)' : 'Pompa Mati\n(MANUAL)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Kelembapan Card
  Widget _buildHumidityCard() {
    return _buildGlassContainer(
      child: SizedBox(
        height: 155,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kelembapan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const Text(
              '68%',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            // Progress Bar dengan Ikon Tetesan Air
            Container(
              height: 18,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.68,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E639),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 4,
                    top: 2,
                    bottom: 2,
                    child: Icon(Icons.water_drop, size: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Ambang <45%',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Suhu Card
  Widget _buildTemperatureCard() {
    return _buildGlassContainer(
      child: SizedBox(
        height: 155,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Suhu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const Text(
              '26.5°C',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Tanah: 25.1°C',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Trend ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 1.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.show_chart, size: 13, color: Colors.black87),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 5. Baterai Card
  Widget _buildBatteryCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          const Text(
            'Baterai',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          // Indikator Baterai Kustom
          Container(
            width: 75,
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87, width: 2.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.92,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  '92%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '3.98V',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Icon(Icons.solar_power_outlined, size: 36, color: Colors.black87),
        ],
      ),
    );
  }

  // 6. Koneksi Card
  Widget _buildConnectionCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          const Text(
            'Koneksi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          // Sinyal Bar & Wifi Icon
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.wifi, size: 24, color: Colors.black87),
                const SizedBox(width: 8),
                _buildSignalBar(height: 8, color: const Color(0xFF00C828)),
                const SizedBox(width: 3),
                _buildSignalBar(height: 16, color: const Color(0xFF00C828)),
                const SizedBox(width: 3),
                _buildSignalBar(height: 24, color: const Color(0xFF00C828)),
                const SizedBox(width: 3),
                _buildSignalBar(height: 32, color: const Color(0xFF00C828)),
                const SizedBox(width: 3),
                _buildSignalBar(height: 40, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'RSSI: -58dBm',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 3),
          const Text(
            'MQTT: Connected',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar({required double height, required Color color}) {
    return Container(
      width: 5.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // 7. Node Selector Dropdown
  Widget _buildNodeSelector() {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: 22,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedNode,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87, size: 26),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => selectedNode = newValue);
            }
          },
          items: nodeList.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text('Pilih Node: $value'),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Custom Painter untuk Grafik Garis Halus (Sparkline Chart)
class SparklineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill background chart area
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00E639).withOpacity(0.35),
          const Color(0xFF00E639).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final greenLinePaint = Paint()
      ..color = const Color(0xFF00C828)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final orangeLinePaint = Paint()
      ..color = const Color(0xFFF28522)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final greenPath = Path();
    final orangePath = Path();

    // Titik kurva hijau (Kelembapan)
    greenPath.moveTo(0, size.height * 0.7);
    greenPath.quadraticBezierTo(size.width * 0.2, size.height * 0.9, size.width * 0.35, size.height * 0.3);
    greenPath.quadraticBezierTo(size.width * 0.5, size.height * 0.45, size.width * 0.65, size.height * 0.15);
    greenPath.quadraticBezierTo(size.width * 0.85, size.height * 0.5, size.width, size.height * 0.3);

    // Titik kurva oranye (Suhu)
    orangePath.moveTo(0, size.height * 0.6);
    orangePath.quadraticBezierTo(size.width * 0.2, size.height * 0.4, size.width * 0.35, size.height * 0.45);
    orangePath.quadraticBezierTo(size.width * 0.55, size.height * 0.4, size.width * 0.65, size.height * 0.15);
    orangePath.quadraticBezierTo(size.width * 0.8, size.height * 0.45, size.width, size.height * 0.1);

    // Fill Path untuk kurva hijau
    final fillPath = Path.from(greenPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(greenPath, greenLinePaint);
    canvas.drawPath(orangePath, orangeLinePaint);

    // Titik puncak (Highlight Dot)
    final dotPaint = Paint()..color = const Color(0xFFF28522);
    final dotOuterPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerPoint = Offset(size.width * 0.65, size.height * 0.15);
    canvas.drawCircle(centerPoint, 4.5, dotPaint);
    canvas.drawCircle(centerPoint, 4.5, dotOuterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}