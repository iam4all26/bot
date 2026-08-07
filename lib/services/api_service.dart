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
  final Set<int> _lockedTradeIds = {};

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isInitialized => _isInit;
  String? get role => _role;
  bool get allowManualTrade => _allowManual;

  ApiService() {
    _initAuth();
  }

  bool isTradeLocked(int id) => _lockedTradeIds.contains(id);

  void toggleTradeLock(int id) {
    if (_lockedTradeIds.contains(id)) {
      _lockedTradeIds.remove(id);
    } else {
      _lockedTradeIds.add(id);
    }
    notifyListeners();
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
    _lockedTradeIds.clear();
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
}
