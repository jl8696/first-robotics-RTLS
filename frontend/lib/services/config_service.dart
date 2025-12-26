import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reader_config.dart';

class ConfigService extends ChangeNotifier {
  final Map<String, List<ReaderConfig>> _configs = {};
  static const String _configKeyPrefix = 'reader_configs_';

  Map<String, List<ReaderConfig>> get configs => Map.unmodifiable(_configs);

  /// Get configurations for a specific venue
  List<ReaderConfig> getConfigsForVenue(String venueMapId) {
    return _configs[venueMapId] ?? [];
  }

  /// Load all configurations from storage
  Future<void> loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      _configs.clear();
      
      for (final key in keys) {
        if (key.startsWith(_configKeyPrefix)) {
          final venueMapId = key.substring(_configKeyPrefix.length);
          final configJson = prefs.getString(key);
          
          if (configJson != null) {
            final List<dynamic> configList = jsonDecode(configJson);
            _configs[venueMapId] = configList
                .map((json) => ReaderConfig.fromJson(json))
                .toList();
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading configurations: $e');
    }
  }

  /// Save configurations for a venue
  Future<void> saveConfigsForVenue(String venueMapId, List<ReaderConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_configKeyPrefix$venueMapId';
      
      final configJson = jsonEncode(configs.map((c) => c.toJson()).toList());
      await prefs.setString(key, configJson);
      
      _configs[venueMapId] = configs;
      notifyListeners();
    } catch (e) {
      print('Error saving configurations: $e');
    }
  }

  /// Add a reader configuration
  Future<void> addReaderConfig(ReaderConfig config) async {
    final configs = getConfigsForVenue(config.venueMapId);
    configs.add(config);
    await saveConfigsForVenue(config.venueMapId, configs);
  }

  /// Update a reader configuration
  Future<void> updateReaderConfig(ReaderConfig config) async {
    final configs = getConfigsForVenue(config.venueMapId);
    final index = configs.indexWhere((c) => c.id == config.id);
    
    if (index != -1) {
      configs[index] = config;
      await saveConfigsForVenue(config.venueMapId, configs);
    }
  }

  /// Delete a reader configuration
  Future<void> deleteReaderConfig(String venueMapId, String configId) async {
    final configs = getConfigsForVenue(venueMapId);
    configs.removeWhere((c) => c.id == configId);
    await saveConfigsForVenue(venueMapId, configs);
  }

  /// Clear all configurations for a venue
  Future<void> clearConfigsForVenue(String venueMapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_configKeyPrefix$venueMapId';
      await prefs.remove(key);
      _configs.remove(venueMapId);
      notifyListeners();
    } catch (e) {
      print('Error clearing configurations: $e');
    }
  }
}

