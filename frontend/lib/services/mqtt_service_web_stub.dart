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
    // Use withPort constructor with URL WITHOUT port, matching working implementation
    // This avoids the URL parsing bug by not including the port in the URL string
    int wsPort = port == 1883 ? 8083 : port;
    if (wsPort != 8083) {
      wsPort = 8083; // Default to 8083 for WebSocket
    }
    
    // Create WebSocket URL WITHOUT port (port will be specified separately in withPort)
    final brokerForUrl = broker == 'localhost' ? '127.0.0.1' : broker;
    final wsUrlWithoutPort = 'ws://$brokerForUrl/mqtt';
    
    try {
      print('MQTT: Connecting to $brokerForUrl:$wsPort...');
      
      // Use withPort constructor matching the working implementation
      _client = MqttBrowserClient.withPort(wsUrlWithoutPort, clientId, wsPort);
      
      _client!.keepAlivePeriod = 20;
      _client!.onConnected = () {
        print('MQTT: Connected');
        _service.onConnected();
      };
      _client!.onDisconnected = () {
        print('MQTT: Disconnected');
        _service.onDisconnected();
      };
      _client!.onSubscribed = (String topic) {
        print('MQTT: Subscribed to topic: $topic');
        _service.onSubscribed(topic);
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();
      
      _client!.connectionMessage = connMessage;
      
      await _client!.connect().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        return true;
      }
      
      _client!.disconnect();
      _client = null;
      return false;
    } catch (e) {
      print('MQTT: Connection error: $e');
      if (_client != null) {
        try {
          _client!.disconnect();
        } catch (_) {
          // Ignore disconnect errors during error recovery
        }
        _client = null;
      }
      return false;
    }
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
      print('MQTT: Error subscribing to topic $topic: $e');
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }
  }
}

