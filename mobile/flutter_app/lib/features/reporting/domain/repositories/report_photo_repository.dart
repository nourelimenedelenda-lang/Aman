import 'dart:typed_data';

abstract interface class ReportPhotoRepository {
  Future<String> savePhoto({
    required String incidentId,
    required List<int> bytes,
    required String fileName,
  });

  Future<Uint8List> loadPhoto(String photoPath);
}
