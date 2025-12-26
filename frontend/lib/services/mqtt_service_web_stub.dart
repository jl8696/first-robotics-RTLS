import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'mqtt_service.dart';

// Web implementation using MqttBrowserClient with WebSockets
class MQTTServiceImpl {
  MqttBrowserClient? _client;
  final MQTTService _service;

  MQTTServiceImpl(this._service);

  Future<bool> connect(String broker, int port, String clientId) async {
    // #region agent log
    print('MQTT Web connect called: broker=$broker, port=$port, clientId=$clientId');
    // #endregion
    
    // Always use port 8083 for WebSocket connection (map 1883 -> 8083)
    int wsPort = port == 1883 ? 8083 : port;
    // Ensure we're using 8083, not any other port
    if (wsPort != 8083) {
      wsPort = 8083;
    }
    
    // Connect to /mqtt path (as required by MQTTX)
    try {
      // For web, use WebSocket URL format (ws:// for port 8083)
      // Format: ws://host:port/path
      // IMPORTANT: The mqtt_client library may parse URLs incorrectly, so we need to ensure
      // the URL is in the exact format it expects. Some versions expect just hostname:port/path
      // without the ws:// protocol prefix, or the library adds it internally.
      final wsUrl = 'ws://$broker:$wsPort/mqtt';
        
        // #region agent log
        print('MQTT Web: Trying to connect to $wsUrl (original port was $port, mapped to $wsPort)');
        print('MQTT Web: wsUrl string length=${wsUrl.length}, contains 8083=${wsUrl.contains('8083')}, contains 1883=${wsUrl.contains('1883')}');
        print('MQTT Web: wsUrl exact value: "$wsUrl"');
        // #endregion
        
        // Try alternative: pass hostname:port/path format (without ws://) if library expects it
        // But first try the full URL format
        final alternativeUrl = '$broker:$wsPort/mqtt';
        print('MQTT Web: Alternative URL format: "$alternativeUrl"');
        
        // Create client with the full WebSocket URL
        // Note: MqttBrowserClient constructor signature: MqttBrowserClient(String server, String clientIdentifier)
        // The library documentation suggests it should accept full WebSocket URLs
        _client = MqttBrowserClient(wsUrl, clientId);
        
        // #region agent log
        print('MQTT Web: Client created with URL: $wsUrl');
        // #endregion
        
        _client!.logging(on: true); // Enable logging to see what URL it's actually using
        _client!.keepAlivePeriod = 20;
        _client!.onConnected = () => _service.onConnected();
        _client!.onDisconnected = () => _service.onDisconnected();
        _client!.onSubscribed = (String topic) => _service.onSubscribed(topic);

        final connMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
        
        _client!.connectionMessage = connMessage;
        
        // Set a timeout for connection
        await _client!.connect().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Connection timeout');
          },
        );

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        // #region agent log
        print('MQTT Web: Successfully connected to $wsUrl');
        // #endregion
        return true;
      }
      
      // Connection failed
      _client!.disconnect();
      _client = null;
    } catch (e) {
      // #region agent log
      print('MQTT Web connection error: $e');
      // #endregion
      if (_client != null) {
        try {
          _client!.disconnect();
        } catch (_) {}
        _client = null;
      }
    }
    
    // #region agent log
    print('MQTT Web: Connection failed');
    // #endregion
    return false;
  }

  Future<void> subscribe(String topic, Function(String) onMessage) async {
    if (_client == null) return;
    
    try {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final recMess = c[0].payload as MqttPublishMessage;
          final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          onMessage(pt);
        }
      });
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }
  }
}

