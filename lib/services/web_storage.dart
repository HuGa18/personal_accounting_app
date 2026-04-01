import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WebStorage {
  static final WebStorage _instance = WebStorage._internal();
  static WebStorage get instance => _instance;
  
  WebStorage._internal();
  
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }
  
  Future<void> saveString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }
  
  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }
  
  Future<void> saveList(String key, List<dynamic> value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }
  
  Future<List<dynamic>> getList(String key) async {
    final prefs = await _prefs;
    final String? data = prefs.getString(key);
    if (data == null) return [];
    return jsonDecode(data) as List<dynamic>;
  }
  
  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
  
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}