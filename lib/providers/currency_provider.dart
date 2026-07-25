import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CurrencyProvider extends ChangeNotifier {
  bool _isNaira = false;
  double _exchangeRate = 1500.0;

  bool get isNaira => _isNaira;

  void toggleCurrency() {
    _isNaira = !_isNaira;
    notifyListeners();
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
    
    if (_isNaira) {
      double nairaVal = val * _exchangeRate;
      if (nairaVal >= 1000000) return '₦${(nairaVal / 1000000).toStringAsFixed(2)}M';
      if (nairaVal >= 1000) return '₦${(nairaVal / 1000).toStringAsFixed(1)}K';
      return '₦${nairaVal.toStringAsFixed(2)}';
    } else {
      if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
      if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
      return '\$${val.toStringAsFixed(2)}';
    }
  }
}
