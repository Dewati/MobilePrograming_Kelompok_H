import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Masukkan ID yang kamu kirim tadi di sini:
    clientId: kIsWeb 
        ? "51242744401-o4dab30biisl4hgb3ih6q85idh11id34.apps.googleusercontent.com" 
        : null,
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final UserCredential result = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = result.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // Create user document in Firestore
        final userModel = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          role: role,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isEmailVerified: user.emailVerified,
          firebaseUid: user.uid,
        );

        print('💾 Saving user to Firestore with role: ${role.name}');
        print('💾 User data: ${userModel.toFirestore()}');

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toFirestore());

        // Send email verification
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }

        return userModel;
      }
      return null;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = result.user;
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          print('🔓 Login: Found user document in Firestore');
          final userData = userDoc.data()!;
          print('🔓 Login: User data from Firestore: $userData');
          return UserModel.fromFirestore(user.uid, userData);
        } else {
          print(
            '❌ Login: User document NOT FOUND in Firestore for UID: ${user.uid}',
          );
          throw Exception('User data not found. Please register first.');
        }
      }
      return null;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Initiate Google Sign-In (for role selection)
  Future<GoogleSignInAccount?> initiateGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      return googleUser;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return null;
    }
  }

  // Sign in with Google (complete flow)
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final User? user = result.user;

      if (user != null) {
        print('🔐 Firebase Google auth successful for UID: ${user.uid}');
        print('🔐 Checking if user exists in Firestore...');

        // Check if user already exists in Firestore by UID (not email)
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          print('✅ Existing user found in Firestore');
          final userData = userDoc.data()!;
          return UserModel.fromFirestore(user.uid, userData);
        } else {
          print(
            '❌ New user - no Firestore document found for UID: ${user.uid}',
          );
          // Return null to show role selection screen
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error in signInWithGoogle: $e');
      throw _handleAuthException(e);
    }
  }

  // Complete Google sign-in with role selection
  Future<UserModel?> completeGoogleSignInWithRole({
    required UserRole role,
    String? userName,
    required String userEmail,
    String? profileImageUrl,
    String? firebaseUid,
  }) async {
    try {
      // First, sign in to Firebase with Google credentials
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final User? user = result.user;

      if (user != null) {
        print('🔐 Google Sign-In successful for user: ${user.email}');
        print('🔐 User photo URL: ${user.photoURL}');
        print('🔐 User display name: ${user.displayName}');

        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? userEmail,
          name: user.displayName ?? userName ?? 'Google User',
          role: role,
          profilePicture: user.photoURL ?? profileImageUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isEmailVerified: user.emailVerified,
          firebaseUid: user.uid,
        );

        print('💾 Saving user to Firestore: ${userModel.toFirestore()}');

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toFirestore());

        print('✅ User saved to Firestore successfully');
        return userModel;
      }
      return null;
    } catch (e) {
      print('❌ Error in completeGoogleSignInWithRole: $e');
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('🚪 Firebase signOut: Starting sign out process...');

      // Sign out from Firebase Auth
      await _firebaseAuth.signOut();
      print('🚪 Firebase Auth signed out');

      // Sign out from Google Sign-In
      await _googleSignIn.signOut();
      print('🚪 Google Sign-In signed out');

      // Additional verification
      final user = _firebaseAuth.currentUser;
      print('🚪 Current user after signOut: ${user?.uid ?? 'null'}');
    } catch (e) {
      print('❌ Sign out error: $e');
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<UserModel?> updateUserProfile({
    String? name,
    String? profilePicture,
    File? profileImageFile,
  }) async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user != null) {
        String? finalProfilePicture;

        // If a new image file is provided, create a local reference
        if (profileImageFile != null) {
          print('📤 Processing new profile picture locally...');

          // Use the local file path as the profile picture reference
          // This allows the app to display the image without uploading to Firebase Storage
          finalProfilePicture = profileImageFile.path;
          print('✅ Profile picture set to local path: $finalProfilePicture');
        } else {
          // Use the provided profilePicture parameter if no file is provided
          finalProfilePicture = profilePicture;
        }

        // Update Firebase Auth profile (only update display name, skip photo URL to avoid Firebase Storage)
        if (name != null) {
          await user.updateDisplayName(name);
        }

        // Note: We skip updating photoURL in Firebase Auth to avoid Firebase Storage dependency
        // The profile picture will be managed locally through Firestore

        // Update Firestore document
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (name != null) updates['name'] = name;
        if (finalProfilePicture != null)
          updates['profilePicture'] = finalProfilePicture;

        await _firestore.collection('users').doc(user.uid).update(updates);
        print('✅ Profile updated successfully in Firestore');

        // Get updated user data
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          return UserModel.fromFirestore(user.uid, userDoc.data()!);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get user data by UID
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('📖 Getting user data for UID: $uid');
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('📖 Firestore data retrieved: $data');
        final user = UserModel.fromFirestore(uid, data);
        print('📖 User model created with role: ${user.role.name}');
        return user;
      }
      print('📖 No user document found for UID: $uid');
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  // Handle authentication exceptions
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email address.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return e.message ?? 'An authentication error occurred.';
      }
    }
    return e.toString();
  }
}
