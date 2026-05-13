import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsProvider with ChangeNotifier {
  static const String _currencyKey = 'selected_currency';
  static const String _biometricKey = 'biometric_enabled';
  
  String _currency = 'AED';
  bool _biometricEnabled = false;
  Map<String, double> _rates = {'AED': 1.0, 'USD': 0.27, 'PKR': 75.0, 'INR': 22.0};
  bool _isFetchingRates = false;

  String get currency => _currency;
  bool get biometricEnabled => _biometricEnabled;
  Map<String, double> get rates => _rates;
  bool get isFetchingRates => _isFetchingRates;

  SettingsProvider() {
    _loadSettings();
    fetchLiveRates();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_currencyKey) ?? 'AED';
    _biometricEnabled = prefs.getBool(_biometricKey) ?? false;
    
    // Try to load from Firestore if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('settings').doc('general').get();
        if (doc.exists) {
          _currency = doc.data()?['currency'] ?? _currency;
          _biometricEnabled = doc.data()?['biometricEnabled'] ?? _biometricEnabled;
        }
      } catch (e) {
        debugPrint("SettingsProvider: Failed to load from Firestore: $e");
      }
    }
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('settings').doc('general').set({
        'biometricEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    notifyListeners();
  }

  Future<void> fetchLiveRates() async {
    _isFetchingRates = true;
    notifyListeners();

    try {
      // Using a free API (ExchangeRate-API) - Replace with your key for production
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/AED'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedRates = Map<String, dynamic>.from(data['rates']);
        _rates = fetchedRates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        debugPrint("SettingsProvider: Live rates updated");
      }
    } catch (e) {
      debugPrint("SettingsProvider: Failed to fetch live rates: $e");
    } finally {
      _isFetchingRates = false;
      notifyListeners();
    }
  }

  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    final rateFrom = _rates[from] ?? 1.0;
    final rateTo = _rates[to] ?? 1.0;
    return (amount / rateFrom) * rateTo;
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, newCurrency);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('settings').doc('general').set({
        'currency': newCurrency,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    notifyListeners();
  }
}
