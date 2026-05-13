import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class PaylioAuthProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  PaylioAuthProvider() {
    // We no longer call _init() here as routing is handled by StreamBuilder in main.dart
  }

  Future<void> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _user = UserModel(
          paylioId: data['uid'] ?? uid,
          name: data['fullName'] ?? 'User',
          email: data['email'] ?? '',
          password: '',
          themePreference: data['themePreference'] ?? 'system',
          preferredCurrency: data['preferredCurrency'] ?? 'AED',
        );
      } else {
        _user = UserModel(
          paylioId: uid,
          name: 'User',
          email: _auth.currentUser?.email ?? '',
          password: '',
          themePreference: 'system',
          preferredCurrency: 'AED',
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _isLoading = false;
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? "Login failed";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "An unexpected error occurred: ${e.toString()}";
    }
  }

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

      // 2. Save profile in Firestore
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': name,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'themePreference': 'system',
        'preferredCurrency': 'AED',
      });

      _isLoading = false;
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? "Signup failed";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

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
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }
}
