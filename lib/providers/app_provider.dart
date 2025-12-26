import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

class AppProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _manualLogout = false; // Flag untuk kontrol manual logout
  final FirebaseAuthService _authService = FirebaseAuthService();

  // SharedPreferences key for manual logout flag
  static const String _manualLogoutKey = 'manual_logout';

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get errorMessage => _errorMessage;
  bool get isTeacher => _currentUser?.role == UserRole.teacher;
  bool get isStudent => _currentUser?.role == UserRole.student;

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set current user
  void setCurrentUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  // Set error message
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Clear error message
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  // Load manual logout flag from SharedPreferences
  Future<void> _loadManualLogoutFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualLogout = prefs.getBool(_manualLogoutKey) ?? false;
      print('📱 Loaded manual logout flag: $_manualLogout');
    } catch (e) {
      print('📱 Error loading manual logout flag: $e');
      _manualLogout = false;
    }
  }

  // Save manual logout flag to SharedPreferences
  Future<void> _saveManualLogoutFlag(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_manualLogoutKey, value);
      _manualLogout = value;
      print('📱 Saved manual logout flag: $_manualLogout');
    } catch (e) {
      print('📱 Error saving manual logout flag: $e');
    }
  }

  // Initialize auth listener
  void initializeAuth() async {
    // Load manual logout flag first
    await _loadManualLogoutFlag();

    _authService.authStateChanges.listen((User? user) async {
      print(
        '🔄 AuthStateChanges: User ${user?.uid}, ManualLogout: $_manualLogout',
      );

      if (user != null && !_manualLogout) {
        // User is signed in and not manually logged out
        try {
          print('🔄 AuthStateChanges: Getting user data...');
          final userData = await _authService.getUserData(user.uid);
          setCurrentUser(userData);
        } catch (e) {
          print('🔄 AuthStateChanges: Error getting user data: $e');
          setErrorMessage('Failed to load user data: ${e.toString()}');
        }
      } else {
        // User is signed out or manually logged out
        print('🔄 AuthStateChanges: Setting user to null');
        setCurrentUser(null);
      }
    });
  }

  // Check login status
  Future<bool> checkLoginStatus() async {
    setLoading(true);

    try {
      // Load manual logout flag first to ensure we have latest value
      await _loadManualLogoutFlag();
      print('🔍 CheckLoginStatus: Manual logout flag: $_manualLogout');

      // If manually logged out, always return false
      if (_manualLogout) {
        print('🔍 CheckLoginStatus: Manual logout detected, not logged in');
        setCurrentUser(null);
        setLoading(false);
        return false;
      }

      final user = _authService.currentUser;
      print('🔍 CheckLoginStatus: Firebase user: ${user?.uid}');

      if (user != null) {
        try {
          final userData = await _authService.getUserData(user.uid);
          if (userData != null) {
            setCurrentUser(userData);
            setLoading(false);
            print(
              '🔍 CheckLoginStatus: User data found, logged in as ${userData.role.name}',
            );
            return true;
          } else {
            print('🔍 CheckLoginStatus: User data not found in Firestore');
            setCurrentUser(null);
            setLoading(false);
            return false;
          }
        } catch (e) {
          print('🔍 CheckLoginStatus: Error getting user data: $e');
          setCurrentUser(null);
          setLoading(false);
          return false;
        }
      }

      print('🔍 CheckLoginStatus: No Firebase user found');
      setCurrentUser(null);
      setLoading(false);
      return false;
    } catch (e) {
      print('🔍 CheckLoginStatus: Exception: $e');
      setCurrentUser(null);
      setLoading(false);
      return false;
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    setLoading(true);
    clearErrorMessage();

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        // Reset manual logout flag when login succeeds
        await _saveManualLogoutFlag(false);
        print('🔓 Login successful: Manual logout flag reset to false');

        setCurrentUser(user);
        setLoading(false);
        return true;
      } else {
        setErrorMessage('Login failed. Please try again.');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setErrorMessage(e.toString());
      setLoading(false);
      return false;
    }
  }

  // Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    print('📝 Register: Selected role: ${role.name}');
    setLoading(true);
    clearErrorMessage();

    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      if (user != null) {
        // Reset manual logout flag when register succeeds
        await _saveManualLogoutFlag(false);
        print('📝 Register successful: Manual logout flag reset to false');

        setCurrentUser(user);
        setLoading(false);
        return true;
      } else {
        setErrorMessage('Registration failed. Please try again.');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setErrorMessage(e.toString());
      setLoading(false);
      return false;
    }
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    setLoading(true);
    clearErrorMessage();

    try {
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // User already has an account
        setCurrentUser(user);
        setLoading(false);
        return user;
      } else {
        // Need to show role selection or user cancelled
        setLoading(false);
        return null;
      }
    } catch (e) {
      setErrorMessage(e.toString());
      setLoading(false);
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      setCurrentUser(null);
      clearErrorMessage();
    } catch (e) {
      setErrorMessage(e.toString());
    }
  }

  // Update profile
  Future<bool> updateProfile({
    String? name,
    String? profilePicture,
    File? profileImageFile,
  }) async {
    setLoading(true);
    clearErrorMessage();

    try {
      final updatedUser = await _authService.updateUserProfile(
        name: name,
        profilePicture: profilePicture,
        profileImageFile: profileImageFile,
      );

      if (updatedUser != null) {
        setCurrentUser(updatedUser);
        setLoading(false);
        return true;
      } else {
        setErrorMessage('Failed to update profile.');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setErrorMessage(e.toString());
      setLoading(false);
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    setLoading(true);
    clearErrorMessage();

    try {
      await _authService.resetPassword(email);
      setLoading(false);
      return true;
    } catch (e) {
      setErrorMessage(e.toString());
      setLoading(false);
      return false;
    }
  }

  // Legacy method - keep for compatibility but redirect to Firebase
  Future<bool> loginLegacy(String email, String password) async {
    setLoading(true);
    clearErrorMessage();

    try {
      // Mock validation for demo purposes - will be removed
      if (email == 'test@test.com' && password == '123456') {
        final user = UserModel(
          uid: 'temp-uid-${email.hashCode}',
          email: email,
          name: 'Test User',
          role: UserRole.student,
          profilePicture:
              'https://ui-avatars.com/api/?name=Test+User&background=3b82f6&color=fff&size=200',
          firebaseUid: 'firebase-uid-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        setCurrentUser(user);
        setLoading(false);
        return true;
      } else {
        setErrorMessage('Email atau password salah');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setErrorMessage('Terjadi kesalahan: $e');
      setLoading(false);
      return false;
    }
  }

  // Complete Google Sign-In flow
  Future<bool> loginWithGoogle() async {
    setLoading(true);
    clearErrorMessage();

    try {
      print('🔐 Starting complete Google Sign-In flow...');

      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // User exists and is authenticated
        print('✅ Google Sign-In successful for existing user');
        await _saveManualLogoutFlag(false);
        setCurrentUser(user);
        setLoading(false);
        return true;
      } else {
        // New user - needs role selection
        print('❌ New user detected - needs role selection');
        setErrorMessage('New user needs role selection');
        setLoading(false);
        return false;
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      setErrorMessage('Gagal login dengan Google: $e');
      setLoading(false);
      return false;
    }
  }

  // Google Sign-In initiate (for role selection)
  Future<Map<String, dynamic>?> initiateGoogleSignIn() async {
    setLoading(true);
    clearErrorMessage();

    try {
      final googleUser = await _authService.initiateGoogleSignIn();

      if (googleUser != null) {
        final userData = {
          'userName': googleUser.displayName ?? 'Google User',
          'userEmail': googleUser.email,
          'profileImageUrl':
              googleUser.photoUrl ??
              'https://ui-avatars.com/api/?name=Google+User&background=16a34a&color=fff&size=200',
          'googleUser': googleUser,
        };

        setLoading(false);
        return userData;
      } else {
        setLoading(false);
        return null;
      }
    } catch (e) {
      setErrorMessage('Gagal login dengan Google: $e');
      setLoading(false);
      return null;
    }
  }

  // Get existing user role by Firebase UID
  Future<UserRole?> getExistingUserRoleByUID(String firebaseUID) async {
    try {
      print('🔍 Checking existing user by Firebase UID: $firebaseUID');

      // Check if user exists in Firestore by Firebase UID (document ID)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUID)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final role = userData['role'] as String;
        print('✅ Found existing user with role: $role');

        // Convert string role to UserRole enum
        if (role == 'teacher' || role == 'guru') {
          return UserRole.teacher;
        } else {
          return UserRole.student;
        }
      }

      print('❌ No existing user found for Firebase UID: $firebaseUID');
      return null; // New user, needs role selection
    } catch (e) {
      print('❌ Error getting existing user role: $e');
      return null; // New user, needs role selection
    }
  }

  // Complete Google Sign In with Role
  Future<bool> completeGoogleSignInWithRole({
    required String role,
    String? userName,
    required String userEmail,
    String? profileImageUrl,
    String? firebaseUid,
  }) async {
    setLoading(true);
    clearErrorMessage();

    try {
      // Convert string role to UserRole enum
      UserRole userRole;
      if (role == 'guru' || role == 'teacher') {
        userRole = UserRole.teacher;
      } else {
        userRole = UserRole.student;
      }

      print('🔐 Completing Google Sign-In with role: ${userRole.name}');
      print(
        '🔐 User data - Name: $userName, Email: $userEmail, Photo: $profileImageUrl',
      );

      final user = await _authService.completeGoogleSignInWithRole(
        role: userRole,
        userName: userName,
        userEmail: userEmail,
        profileImageUrl: profileImageUrl,
        firebaseUid: firebaseUid,
      );

      if (user != null) {
        // Reset manual logout flag when Google login succeeds
        await _saveManualLogoutFlag(false);
        print('🔓 Google Login successful: Manual logout flag reset to false');

        setCurrentUser(user);
        setLoading(false);
        return true;
      } else {
        setErrorMessage('Gagal menyelesaikan login Google');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setErrorMessage('Error Google login: $e');
      setLoading(false);
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    setLoading(true);

    try {
      print('🚪 Logging out user...');

      // Set manual logout flag FIRST before signing out
      await _saveManualLogoutFlag(true);
      print('🚪 Manual logout flag set to true');

      await _authService.signOut();
      setCurrentUser(null);
      clearErrorMessage();
      print('🚪 User logged out successfully - auth state cleared');
      setLoading(false);
    } catch (e) {
      print('❌ Logout error: $e');
      setErrorMessage('Failed to logout');
      setLoading(false);
    }
  } // Clear all data

  void clear() {
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  // Add user getter alias for compatibility
  UserModel? get user => _currentUser;
}
