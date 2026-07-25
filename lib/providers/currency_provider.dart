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
    
    // Check if it's a negative number, then work with the absolute value
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
