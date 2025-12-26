import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'mqtt_service.dart';

class MQTTServiceImpl {
  MqttServerClient? _client;
  final MQTTService _service;

  MQTTServiceImpl(this._service);

  Future<bool> connect(String broker, int port, String clientId) async {
    try {
      _client = MqttServerClient.withPort(broker, clientId, port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 20;
      _client!.onConnected = () => _service.onConnected();
      _client!.onDisconnected = () => _service.onDisconnected();
      _client!.onSubscribed = (String topic) => _service.onSubscribed(topic);

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        return true;
      }
      return false;
    } catch (e) {
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
      // Error subscribing
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }
  }
}

