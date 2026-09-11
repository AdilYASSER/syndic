// lib/services/upload_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✅ UPLOAD D'UNE IMAGE
  Future<String?> uploadImage(dynamic image, String folder) async {
    try {
      String fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      if (kIsWeb && image is Uint8List) {
        // ✅ Version Web
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
        );
        await ref.putData(image, metadata);
        final url = await ref.getDownloadURL();
        return url;
      } else if (!kIsWeb && image is File) {
        // ✅ Version Mobile
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
        );
        await ref.putFile(image, metadata);
        final url = await ref.getDownloadURL();
        return url;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur upload image: $e');
      return null;
    }
  }

  // ✅ UPLOAD DE PLUSIEURS IMAGES
  Future<List<String>> uploadMultipleImages(List<dynamic> images, String folder) async {
    List<String> urls = [];
    for (var image in images) {
      final url = await uploadImage(image, folder);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }
}