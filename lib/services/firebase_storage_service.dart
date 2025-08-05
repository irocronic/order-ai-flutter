// lib/services/firebase_storage_service.dart
import 'dart:io';
import 'dart:typed_data'; // Uint8List için
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Web platformunu kontrol etmek için
import 'package:path/path.dart' as path; // Dosya adını almak için

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static Future<String?> uploadImage({
    File? imageFile,
    Uint8List? imageBytes,
    required String fileName,
    required String folderPath,
  }) async {
    if (imageFile == null && imageBytes == null) {
      throw ArgumentError('imageFile veya imageBytes sağlanmalıdır.');
    }
    if (kIsWeb && imageBytes == null) {
      throw ArgumentError('Web platformu için imageBytes sağlanmalıdır.');
    }
    if (!kIsWeb && imageFile == null) {
      throw ArgumentError('Mobil platformlar için imageFile sağlanmalıdır.');
    }

    try {
      final storagePath = '$folderPath/$fileName';
      final ref = _storage.ref().child(storagePath);
      UploadTask uploadTask;

      if (kIsWeb) {
        // Web için Uint8List yükle
        uploadTask = ref.putData(imageBytes!);
      } else {
        // Mobil için File yükle
        uploadTask = ref.putFile(imageFile!);
      }

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Firebase Storage yükleme hatası: $e');
      return null;
    }
  }
  static Future<String?> getDownloadUrl(String storagePath) async {
    if (storagePath.isEmpty) return null;
    try {
      final ref = _storage.ref().child(storagePath);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Firebase Storage indirme URL alma hatası ($storagePath): $e');
      return null;
    }
  }
}
