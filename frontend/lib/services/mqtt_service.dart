import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/team_location.dart';
import '../utils/mqtt_message_parser.dart';
import '../utils/debug_logger.dart';

// Conditional imports - only import mqtt_client for non-web platforms
import 'mqtt_service_impl.dart' if (dart.library.html) 'mqtt_service_web_stub.dart';

class MQTTService extends ChangeNotifier {
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  final Map<String, List<TeamLocation>> _teamLocations = {};
  bool _isDisposed = false;
  
  // MQTT Configuration - should be configurable via settings
  String _broker = '127.0.0.1';
  int _port = 8083; // Default to 8083 for WebSocket
  String _clientId = 'rtls_flutter_client';
  String _topic = 'Robot Locations';
  
  late final MQTTServiceImpl _impl;

  // #region agent log
  void _log(String message, Map<String, dynamic> data) {
    debugLog('mqtt_service.dart', message, data, hypothesisId: 'B');
  }
  // #endregion

  MQTTService() {
    _impl = MQTTServiceImpl(this);
    // #region agent log
    _log('MQTTService CONSTRUCTOR', {'isDisposed': _isDisposed});
    // #endregion
  }

  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  Map<String, List<TeamLocation>> get teamLocations => Map.unmodifiable(_teamLocations);

  /// Get team locations for a specific reader
  List<TeamLocation> getLocationsForReader(String readerName) {
    return _teamLocations[readerName] ?? [];
  }

  /// Configure MQTT broker connection details
  void configure({
    String? broker,
    int? port,
    String? clientId,
    String? topic,
  }) {
    if (broker != null) _broker = broker;
    if (port != null) _port = port;
    if (clientId != null) _clientId = clientId;
    if (topic != null) _topic = topic;
  }

  /// Connect to MQTT broker
  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }

    // Ensure we're using the correct port (8083 for WebSocket)
    if (_port == 1883) {
      _port = 8083;
    }

    _connectionStatus = 'Connecting...';
    // #region agent log
    _log('connect notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
    // #endregion
    if (!_isDisposed) notifyListeners();
    // #region agent log
    _log('connect notifyListeners AFTER', {'isDisposed': _isDisposed});
    // #endregion

    try {
      final connected = await _impl.connect(_broker, _port, _clientId);
      
      if (connected) {
        _connectionStatus = 'Connected';
        _isConnected = true;
        await subscribe();
        // #region agent log
        _log('connect SUCCESS notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
        // #endregion
        if (!_isDisposed) notifyListeners();
        // #region agent log
        _log('connect SUCCESS notifyListeners AFTER', {'isDisposed': _isDisposed});
        // #endregion
        return true;
      } else {
        _connectionStatus = 'Connection failed';
        _isConnected = false;
        // #region agent log
        _log('connect FAILED notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
        // #endregion
        if (!_isDisposed) notifyListeners();
        // #region agent log
        _log('connect FAILED notifyListeners AFTER', {'isDisposed': _isDisposed});
        // #endregion
        return false;
      }
    } catch (e) {
      _connectionStatus = 'Error: $e';
      _isConnected = false;
      // #region agent log
      _log('connect ERROR notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners, 'error': e.toString()});
      // #endregion
      if (!_isDisposed) notifyListeners();
      // #region agent log
      _log('connect ERROR notifyListeners AFTER', {'isDisposed': _isDisposed});
      // #endregion
      return false;
    }
  }

  /// Subscribe to Robot Locations topic
  Future<void> subscribe() async {
    if (!_isConnected) {
      return;
    }

    try {
      await _impl.subscribe(_topic, _handleMessage);
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Handle incoming MQTT messages
  void _handleMessage(String message) {
    try {
      final parsedData = MQTTMessageParser.parseMessage(message);
      
      // Update team locations
      parsedData.forEach((readerName, locations) {
        _teamLocations[readerName] = locations;
      });
      
      // #region agent log
      _log('_handleMessage notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
      // #endregion
      if (!_isDisposed) notifyListeners();
      // #region agent log
      _log('_handleMessage notifyListeners AFTER', {'isDisposed': _isDisposed});
      // #endregion
    } catch (e) {
      print('Error handling MQTT message: $e');
    }
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    if (_isConnected) {
      await _impl.disconnect();
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _teamLocations.clear();
      // #region agent log
      _log('disconnect notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
      // #endregion
      if (!_isDisposed) notifyListeners();
      // #region agent log
      _log('disconnect notifyListeners AFTER', {'isDisposed': _isDisposed});
      // #endregion
    }
  }

  void onConnected() {
    // Connection handled by mqtt_service_web_stub.dart
  }

  void onDisconnected() {
    print('MQTT Client disconnected');
    _isConnected = false;
    _connectionStatus = 'Disconnected';
    // #region agent log
    _log('onDisconnected notifyListeners BEFORE', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
    // #endregion
    if (!_isDisposed) notifyListeners();
    // #region agent log
    _log('onDisconnected notifyListeners AFTER', {'isDisposed': _isDisposed});
    // #endregion
  }

  void onSubscribed(String topic) {
    // Subscription handled by mqtt_service_web_stub.dart
  }

  @override
  void dispose() {
    // #region agent log
    _log('dispose START', {'isDisposed': _isDisposed, 'hasListeners': hasListeners});
    // #endregion
    _isDisposed = true;
    disconnect();
    // #region agent log
    _log('dispose disconnect CALLED', {'isDisposed': _isDisposed});
    // #endregion
    super.dispose();
    // #region agent log
    _log('dispose COMPLETE', {});
    // #endregion
  }
}
