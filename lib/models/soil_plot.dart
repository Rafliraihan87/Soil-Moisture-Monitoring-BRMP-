import 'soil_record.dart';

class SoilPlot {
  final String id;
  String name;
  String? imageData;
  final List<SoilRecord> records;

  SoilPlot({
    required this.id,
    required this.name,
    this.imageData,
    required this.records,
  });
}
