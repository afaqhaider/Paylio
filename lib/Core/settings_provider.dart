import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _currencyKey = 'selected_currency';
  String _currency = 'AED';

  String get currency => _currency;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_currencyKey) ?? 'AED';
    notifyListeners();
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, newCurrency);
    notifyListeners();
  }
}
