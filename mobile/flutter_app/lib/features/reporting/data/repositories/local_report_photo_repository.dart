import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/report_photo_repository.dart';

class LocalReportPhotoRepository implements ReportPhotoRepository {
  const LocalReportPhotoRepository();

  @override
  Future<String> savePhoto({
    required String incidentId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final extension = _extensionOf(fileName);
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}report_photos',
    );
    await directory.create(recursive: true);
    final photo = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await photo.writeAsBytes(bytes, flush: true);
    return photo.path;
  }

  @override
  Future<Uint8List> loadPhoto(String photoPath) async =>
      File(photoPath).readAsBytes();

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'jpg';
    final extension = fileName.substring(dot + 1).toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) return 'jpg';
    return extension;
  }
}
