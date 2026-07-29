import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CurrencyProvider extends ChangeNotifier {
  bool _isNaira = false;
  double _exchangeRate = 1500.0;

  bool get isNaira => _isNaira;
  double get exchangeRate => _exchangeRate; // FIXED: Expose raw numerical rate for the calculator

  CurrencyProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isNaira = prefs.getBool('is_naira_preferred') ?? false;
      notifyListeners();
    } catch (e) {
      // Fallback to false if prefs not available
    }
  }

  Future<void> toggleCurrency() async {
    _isNaira = !_isNaira;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_naira_preferred', _isNaira);
    } catch (e) {
      // Ignore write errors
    }
  }

  Future<void> fetchLiveRate(ApiService api) async {
    try {
      final res = await api.getEndpoint('exchange_rate.php');
      if (res['status'] == 'success' && res['rate'] != null) {
        _exchangeRate = double.tryParse(res['rate'].toString()) ?? _exchangeRate;
        notifyListeners();
      }
    } catch (e) {
      // Use fallback if offline
    }
  }

  String format(dynamic usdValue) {
    if (usdValue == null) return '-';
    double val = double.tryParse(usdValue.toString()) ?? 0.0;
    
    bool isNegative = val < 0;
    double absVal = val.abs();
    
    if (_isNaira) {
      double nairaVal = absVal * _exchangeRate;
      String prefix = isNegative ? '-₦' : '₦';
      
      if (nairaVal >= 1000000) return '$prefix${(nairaVal / 1000000).toStringAsFixed(2)}M';
      if (nairaVal >= 1000) return '$prefix${(nairaVal / 1000).toStringAsFixed(1)}K';
      return '$prefix${nairaVal.toStringAsFixed(2)}';
    } else {
      String prefix = isNegative ? '-\$' : '\$';
      
      if (absVal >= 1000000) return '$prefix${(absVal / 1000000).toStringAsFixed(2)}M';
      if (absVal >= 1000) return '$prefix${(absVal / 1000).toStringAsFixed(1)}K';
      return '$prefix${absVal.toStringAsFixed(2)}';
    }
  }
}
