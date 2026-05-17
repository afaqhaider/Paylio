import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/notification_service.dart';
import 'user_model.dart';

class LedGixAuthProvider extends ChangeNotifier {
  // --- Firebase Service Getters ---
  // Using lazy getters to ensure Firebase is initialized before access.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // --- State Variables ---
  UserModel? _user;
  bool _isLoading = false;

  // --- Public Getters ---
  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  LedGixAuthProvider() {
    // Note: Auth routing is now handled declaratively by AuthGate using 
    // FirebaseAuth.instance.authStateChanges() in main.dart
  }

  bool _notificationsInitialized = false;

  /// Fetches the user profile from Firestore and updates the local [_user] state.
  /// This is typically called once upon login or app startup.
  Future<void> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _user = UserModel(
          ledgixId: data['uid'] ?? uid,
          name: data['fullName'] ?? 'User',
          email: data['email'] ?? '',
          password: '', // Never store passwords in the model
          themePreference: data['themePreference'] ?? 'system',
          preferredCurrency: data['preferredCurrency'] ?? 'AED',
        );
        debugPrint("Firestore profile loaded: ${data['fullName']} ($uid)");
      } else {
        // Create a local fallback if the document doesn't exist (e.g. legacy users)
        _user = UserModel(
          ledgixId: uid,
          name: 'User',
          email: _auth.currentUser?.email ?? '',
          password: '',
          themePreference: 'system',
          preferredCurrency: 'AED',
        );
        debugPrint("Firestore doc missing for $uid. Using local fallback.");
      }

      if (!_notificationsInitialized) {
        NotificationService.initialize();
        _notificationsInitialized = true;
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  /// Signs in the user with email and password via Firebase Auth.
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _isLoading = false;
      debugPrint("Login success: $email");
      return null; // Indicates success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Login failure: ${e.code} - ${e.message}");
      return e.message ?? "Login failed";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Login error: ${e.toString()}");
      return "An unexpected error occurred.";
    }
  }

  /// Creates a new user in Firebase Auth and a corresponding profile in Firestore.
  /// Ensures the Firestore document is created only once during the signup process.
  Future<String?> signup(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Create user in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. Save profile in Firestore using the unique UID as doc ID
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': name,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'themePreference': 'system',
        'preferredCurrency': 'AED',
      });

      _isLoading = false;
      debugPrint("Signup success: $email (UID: $uid)");
      return null; // Indicates success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Signup failure: ${e.code} - ${e.message}");
      return e.message ?? "Signup failed";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Signup error: ${e.toString()}");
      return "An error occurred during account creation.";
    }
  }

  /// Logs the user out and clears the local state.
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null; // Clear local user state
      notifyListeners();
      debugPrint("User logged out and local state cleared.");
    } catch (e) {
      debugPrint("Error during logout: $e");
    }
  }

  /// Updates the user's profile in Firestore and syncs the local state.
  Future<void> updateProfile(UserModel updatedUser) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'fullName': updatedUser.name,
          'themePreference': updatedUser.themePreference,
          'preferredCurrency': updatedUser.preferredCurrency,
        });
        _user = updatedUser;
        notifyListeners();
        debugPrint("Profile updated successfully in Firestore.");
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }
}
