import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/soil_plot.dart';
import '../models/soil_record.dart';

class PlantService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PlantService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User belum login.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get plantsCollection =>
      _firestore.collection('users').doc(_uid).collection('plants');

  Future<List<SoilPlot>> getPlants() async {
    final snapshot = await plantsCollection.orderBy('createdAt').get();
    final loaded = <SoilPlot>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final records = <SoilRecord>[];

      try {
        final measurements = await doc.reference
            .collection('measurements')
            .orderBy('timestamp', descending: false)
            .get();

        for (var i = 0; i < measurements.docs.length; i++) {
          final measurement = measurements.docs[i].data();
          final ts = measurement['timestamp'];

          final DateTime timestamp;
          if (ts is Timestamp) {
            timestamp = ts.toDate();
          } else if (ts is String) {
            timestamp = DateTime.tryParse(ts) ?? DateTime.now();
          } else {
            timestamp = DateTime.now();
          }

          records.add(
            SoilRecord(
              testNumber: i + 1,
              avgMoisture: (measurement['moisture'] as num?)?.toInt() ?? 0,
              avgTemp: (measurement['temperature'] as num?)?.toDouble() ?? 0,
              timestamp: timestamp,
            ),
          );
        }
      } catch (_) {
        // Jika history gagal dibaca, tanaman tetap ditampilkan.
      }

      loaded.add(
        SoilPlot(
          id: doc.id,
          name: (data['name'] as String?) ?? 'Tanaman',
          imageData: data['imageData'] as String?,
          records: records,
        ),
      );
    }

    return loaded;
  }

  Future<DocumentReference<Map<String, dynamic>>> addPlant({
    required String name,
    String? imageData,
  }) {
    return plantsCollection.add({
      'name': name,
      'imageData': imageData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePlant({
    required String plantId,
    required String name,
    String? imageData,
  }) {
    return plantsCollection.doc(plantId).update({
      'name': name,
      'imageData': imageData,
    });
  }

  Future<void> deletePlant(String plantId) async {
    final plantRef = plantsCollection.doc(plantId);
    final measurements =
        await plantRef.collection('measurements').limit(450).get();

    // Delete measurements in chunks so a plant with many records is safe.
    var docs = measurements.docs;
    while (docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      final next = await plantRef.collection('measurements').limit(450).get();
      docs = next.docs;
    }

    await plantRef.delete();
  }
}
