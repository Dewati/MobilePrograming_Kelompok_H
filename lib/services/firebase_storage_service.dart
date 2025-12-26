import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constructor to debug storage configuration
  FirebaseStorageService() {
    print('🔥 Firebase Storage - Bucket: ${_storage.bucket}');
    print('🔥 Firebase Storage - App: ${_storage.app.name}');
  }

  // Upload profile picture to Firebase Storage
  Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique filename
      final String fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create reference to Firebase Storage
      final Reference storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child(fileName);

      // Set metadata for the image
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload the file
      print('📤 Uploading profile picture: $fileName');
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Profile picture uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  // Delete old profile picture (optional cleanup)
  Future<void> deleteProfilePicture(String imageUrl) async {
    try {
      if (imageUrl.contains('firebase')) {
        // Extract the file path from URL
        final Reference ref = _storage.refFromURL(imageUrl);
        await ref.delete();
        print('🗑️ Old profile picture deleted');
      }
    } catch (e) {
      print('⚠️ Warning: Could not delete old profile picture: $e');
      // Don't throw error here as it's not critical
    }
  }

  // Upload any file to Firebase Storage
  Future<String> uploadFile(File file, String filePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Firebase Storage - File path: $filePath');
      print('🔍 Firebase Storage - User: ${user.email}');
      print('🔐 Firebase Auth - User ID: ${user.uid}');

      // Get and print auth token for debugging
      try {
        final String? token = await user.getIdToken();
        print('🔐 Firebase Auth - Token exists: ${token?.isNotEmpty ?? false}');
      } catch (e) {
        print('❌ Error getting auth token: $e');
      }

      // Try different storage paths in case of rule restrictions
      final String bucketName = _storage.bucket;
      print('🔥 Firebase Storage - Bucket: $bucketName');

      // Try simplified path first
      final String simplePath = 'files/${path.basename(file.path)}';
      print('🔍 Trying simplified path: $simplePath');

      final Reference storageRef = _storage.ref().child(simplePath);

      // Set metadata based on file type
      final String extension = path.extension(file.path).toLowerCase();
      String? contentType;
      print('🔍 Firebase Storage - File extension: $extension');

      if (['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
        contentType = 'image/${extension.substring(1)}';
      } else if (['.pdf'].contains(extension)) {
        contentType = 'application/pdf';
      } else if (['.doc', '.docx'].contains(extension)) {
        contentType = 'application/msword';
      } else if (['.txt'].contains(extension)) {
        contentType = 'text/plain';
      }

      final SettableMetadata metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'userId': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload the file
      print('📤 Uploading file: $filePath');
      print('🔍 Metadata: ${metadata.customMetadata}');

      final UploadTask uploadTask = storageRef.putFile(file, metadata);
      print('🔍 Upload task created');

      // Wait for upload to complete
      print('⏳ Waiting for upload to complete...');
      final TaskSnapshot snapshot = await uploadTask;
      print('✅ Upload completed');

      // Get download URL
      print('🔗 Getting download URL...');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ File uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading file: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  // Get profile pictures folder reference
  Reference get profilePicturesRef => _storage.ref().child('profile_pictures');

  // Check if storage is available
  Future<bool> isStorageAvailable() async {
    try {
      await _storage.ref().child('test').getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }
}
