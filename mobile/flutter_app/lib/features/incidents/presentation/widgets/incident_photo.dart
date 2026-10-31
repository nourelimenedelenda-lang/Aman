import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../reporting/domain/repositories/report_photo_repository.dart';

class IncidentPhoto extends StatelessWidget {
  const IncidentPhoto({
    super.key,
    required this.path,
    required this.photoRepository,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final ReportPhotoRepository? photoRepository;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        height: height,
        width: double.infinity,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _unavailable(),
      );
    }
    if (path.startsWith('users/')) {
      final repository = photoRepository;
      if (repository == null) return _unavailable();
      return FutureBuilder<Uint8List>(
        future: repository.loadPhoto(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _unavailable();
          if (!snapshot.hasData) {
            return SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return Image.memory(
            snapshot.data!,
            height: height,
            width: double.infinity,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _unavailable(),
          );
        },
      );
    }
    return Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _unavailable(),
    );
  }

  Widget _unavailable() => SizedBox(
    height: height,
    child: const Center(
      child: Text(
        'The attached photo is unavailable on this device.',
        style: TextStyle(color: Colors.black54),
      ),
    ),
  );
}
