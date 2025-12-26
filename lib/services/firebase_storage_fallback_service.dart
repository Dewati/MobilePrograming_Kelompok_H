import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageFallbackService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Convert file to base64 string for Firestore storage
  Future<String> convertFileToBase64(File file) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('📄 Converting file to base64: ${file.path}');

      // Check file size (limit to 1MB for Firestore)
      final int fileSize = await file.length();
      print('📊 File size: $fileSize bytes');

      if (fileSize > 1024 * 1024) {
        // 1MB limit
        throw Exception('File too large. Maximum size is 1MB.');
      }

      // Read file as bytes
      final Uint8List bytes = await file.readAsBytes();

      // Convert to base64
      final String base64String = base64Encode(bytes);

      // Create data URL with mime type
      final String fileName = file.path.split('/').last;
      final String extension = fileName.split('.').last.toLowerCase();

      String mimeType = 'application/octet-stream';
      switch (extension) {
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'doc':
          mimeType = 'application/msword';
          break;
        case 'docx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'txt':
          mimeType = 'text/plain';
          break;
      }

      final String dataUrl = 'data:$mimeType;base64,$base64String';

      print('✅ File converted to base64 successfully');
      print('📊 Base64 length: ${dataUrl.length} characters');

      return dataUrl;
    } catch (e) {
      print('❌ Error converting file to base64: $e');
      throw Exception('Failed to convert file: $e');
    }
  }

  // Extract filename from data URL or file path
  String getFileNameFromDataUrl(String dataUrl, [String? originalPath]) {
    if (originalPath != null) {
      return originalPath.split('/').last;
    }
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Check if string is a data URL
  bool isDataUrl(String url) {
    return url.startsWith('data:');
  }

  // Get file size from data URL
  int getFileSizeFromDataUrl(String dataUrl) {
    try {
      final String base64Part = dataUrl.split(',')[1];
      final Uint8List bytes = base64Decode(base64Part);
      return bytes.length;
    } catch (e) {
      return 0;
    }
  }

  // Get MIME type from data URL
  String getMimeTypeFromDataUrl(String dataUrl) {
    try {
      final String header = dataUrl.split(',')[0];
      final RegExp mimeRegex = RegExp(r'data:([^;]+)');
      final Match? match = mimeRegex.firstMatch(header);
      return match?.group(1) ?? 'application/octet-stream';
    } catch (e) {
      return 'application/octet-stream';
    }
  }
}
