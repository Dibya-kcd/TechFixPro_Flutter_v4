import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoService {
  static final _storage = FirebaseStorage.instance;

  /// Compresses an image to be below 100 KB
  static Future<File?> compressImage(String path) async {
    final file = File(path);
    final size = await file.length();
    
    // If already below 100 KB, no need to compress heavily
    if (size < 100 * 1024) return file;

    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';

    // Start with quality 80 and reduce until < 100 KB or quality < 10
    int quality = 80;
    XFile? result;
    
    while (quality > 10) {
      result = await FlutterImageCompress.compressAndGetFile(
        path,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      if (result == null) break;
      final newSize = await File(result.path).length();
      if (newSize < 100 * 1024) break;
      quality -= 15;
    }
    
    return result != null ? File(result.path) : file;
  }

  /// Uploads a photo to Firebase Storage and returns the download URL
  static Future<String?> uploadPhoto(String path, String folder) async {
    try {
      final compressed = await compressImage(path);
      if (compressed == null) return null;

      final ref = _storage.ref().child('$folder/${const Uuid().v4()}.jpg');
      final uploadTask = ref.putFile(compressed);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('[PhotoService] Error uploading photo: $e');
      return null;
    }
  }

  /// Batch upload photos
  static Future<List<String>> uploadPhotos(List<String> paths, String folder) async {
    final urls = <String>[];
    for (final path in paths) {
      if (path.startsWith('http')) {
        urls.add(path);
        continue;
      }
      final url = await uploadPhoto(path, folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
