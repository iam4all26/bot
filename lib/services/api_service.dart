import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'https://bot.kainuwa.africa/mobile';
  
  String? _token;
  String? _role;
  bool _isInit = false;
  bool _allowManual = false;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isInitialized => _isInit;
  String? get role => _role;
  bool get allowManualTrade => _allowManual;

  ApiService() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      _token = await _storage.read(key: 'api_token');
      _role = await _storage.read(key: 'user_role');
      final am = await _storage.read(key: 'allow_manual');
      _allowManual = am == 'true';
    } catch (e) {
      await _storage.deleteAll().catchError((_) {});
    }
    _isInit = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      
      final data = jsonDecode(res.body);
      
      if (data['status'] == 'success') {
        _token = data['token'] ?? data['api_token'] ?? (data['data'] != null ? (data['data']['token'] ?? data['data']['api_token']) : null);
        _allowManual = (data['allow_manual_trade'] == 1 || data['allow_manual_trade'] == '1' || (data['data'] != null && data['data']['allow_manual_trade'] == 1));
        _role = data['role'] ?? (data['data'] != null ? data['data']['role'] : 'user');

        if (_token != null && _token!.isNotEmpty) {
          try {
            await _storage.write(key: 'api_token', value: _token);
            await _storage.write(key: 'user_role', value: _role);
            await _storage.write(key: 'allow_manual', value: _allowManual.toString());
          } catch (e) {
            await _storage.deleteAll().catchError((_) {});
          }
          notifyListeners();
        } else {
          return {'status': 'error', 'message': 'Authentication token missing from server response.'};
        }
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Network connection failed. Please try again.'};
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _allowManual = false;
    try {
      await _storage.delete(key: 'api_token');
      await _storage.delete(key: 'user_role');
      await _storage.delete(key: 'allow_manual');
    } catch (e) {
      // Ignore
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> getEndpoint(String endpoint) async {
    if (!isAuthenticated) return {'status': 'error', 'message': 'Unauthorized'};
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'GET Parse Error: $e'};
    }
  }

  Future<Map<String, dynamic>> postEndpoint(String endpoint, Map<String, dynamic> payload) async {
    if (!isAuthenticated) return {'status': 'error', 'message': 'Unauthorized'};
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'API Error: $e'};
    }
  }

  // ==========================================
  // MARKET FEATURE ENDPOINTS
  // ==========================================

  Future<Map<String, dynamic>> fetchMarketHub() async {
    return getEndpoint('market.php?action=fetch_hub');
  }

  Future<Map<String, dynamic>> fetchDepositAddresses() async {
    return getEndpoint('market.php?action=fetch_deposit_addresses');
  }

  Future<Map<String, dynamic>> buyCryptoInitiate({
    required String asset,
    required double ngnAmount,
  }) async {
    return postEndpoint('market.php?action=buy_initiate', {
      'asset': asset,
      'ngn_amount': ngnAmount,
    });
  }

  Future<Map<String, dynamic>> getNigerianBanks() async {
    return getEndpoint('market.php?action=get_banks');
  }

  Future<Map<String, dynamic>> resolveBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    return postEndpoint('market.php?action=resolve_bank', {
      'account_number': accountNumber,
      'bank_code': bankCode,
    });
  }

  Future<Map<String, dynamic>> checkPinStatus() async {
    return getEndpoint('market.php?action=check_pin_status');
  }

  Future<Map<String, dynamic>> setWithdrawalPin({
    required String password,
    required String pin,
  }) async {
    return postEndpoint('market.php?action=set_pin', {
      'password': password,
      'pin': pin,
    });
  }

  Future<Map<String, dynamic>> withdrawCrypto({
    required String asset,
    required double amount,
    required String destinationAddress,
    required String pin,
  }) async {
    return postEndpoint('market.php?action=withdraw_crypto', {
      'asset': asset,
      'amount': amount,
      'destination_address': destinationAddress,
      'withdrawal_pin': pin,
    });
  }

  Future<Map<String, dynamic>> withdrawNaira({
    required String asset,
    required double amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required String pin,
  }) async {
    return postEndpoint('market.php?action=withdraw_naira', {
      'asset': asset,
      'amount': amount,
      'bank_code': bankCode,
      'account_number': accountNumber,
      'account_name': accountName,
      'withdrawal_pin': pin,
    });
  }
}
