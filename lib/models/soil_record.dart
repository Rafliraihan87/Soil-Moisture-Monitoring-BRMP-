class SoilRecord {
  final int testNumber;
  final int avgMoisture;
  final double avgTemp;
  final DateTime timestamp;
  bool isSynced;

  SoilRecord({
    required this.testNumber,
    required this.avgMoisture,
    required this.avgTemp,
    required this.timestamp,
    this.isSynced = false,
  });
}
