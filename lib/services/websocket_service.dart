import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/message_model.dart';
import 'auth_service.dart';
import 'log_service.dart';

/// WebSocketService manages real-time messaging stream with Spring Boot /chat endpoint.
/// Includes automatic reconnection logic when disconnected or on network drop.
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _isManuallyDisconnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 3;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _channel != null;

  Future<bool> connect() async {
    if (_channel != null) return true;

    if (_isConnecting) {
      LogService.ws('WebSocket connection already in progress, awaiting...');
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_channel != null) return true;
        if (!_isConnecting) break;
      }
      if (_channel != null) return true;
    }

    _isManuallyDisconnected = false;
    _reconnectTimer?.cancel();
    _isConnecting = true;

    try {
      final authService = AuthService();
      final ticket = await authService.fetchWsTicket();

      if (ticket == null || ticket.isEmpty) {
        LogService.error('WebSocket Error: Could not obtain one-time ticket');
        _isConnecting = false;
        _scheduleReconnect();
        return false;
      }

      final wsUri = Uri.parse('${AppConfig.wsUrl}/chat?ticket=$ticket');
      LogService.ws('Connecting to WebSocket: $wsUri');

      _channel = WebSocketChannel.connect(wsUri);
      _reconnectDelaySeconds =
          3; // Reset exponential backoff on connection creation
      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          LogService.ws('WS Message Received', data.toString());
          try {
            final Map<String, dynamic> jsonMsg = jsonDecode(data);
            _messageController.add(jsonMsg);
          } catch (e) {
            LogService.error('JSON Parsing Error on WS message', e);
          }
        },
        onError: (error) {
          LogService.error('WebSocket Stream Error', error);
          _handleDisconnection();
        },
        onDone: () {
          LogService.ws('WebSocket Connection Closed');
          _handleDisconnection();
        },
      );
      LogService.ws('WebSocket Connected Successfully');
      _isConnecting = false;
      return true;
    } catch (e, st) {
      LogService.error('Failed to connect WebSocket', e, st);
      _isConnecting = false;
      _handleDisconnection();
      return false;
    }
  }

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_channel != null) {
        try {
          final pingMsg = MessageModel(
            type: 'PING',
            sender: '',
            receiver: '',
            message: 'ping',
            status: 'SENT',
            timeStamp: DateTime.now().millisecondsSinceEpoch,
          );
          _channel!.sink.add(jsonEncode(pingMsg.toJson()));
        } catch (_) {
          _handleDisconnection();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleDisconnection() {
    _stopHeartbeat();
    _channel = null;
    if (!_isManuallyDisconnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _reconnectDelaySeconds;
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_isManuallyDisconnected && _channel == null) {
        LogService.ws(
            'Attempting automatic WebSocket reconnection (delay ${delay}s)...');
        // Exponential backoff capped at 30 seconds
        _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(3, 30);
        connect();
      }
    });
  }

  Future<bool> sendMessage(MessageModel message) async {
    if (_channel == null) {
      LogService.ws(
          'WS channel is null. Attempting on-demand reconnection before sending...');
      final connected = await connect();
      if (!connected || _channel == null) {
        LogService.error(
            'Cannot send WS message: channel is null after reconnection attempt');
        return false;
      }
    }

    try {
      final jsonString = jsonEncode(message.toJson());
      LogService.ws('Sending WS Message', jsonString);
      _channel!.sink.add(jsonString);
      return true;
    } catch (e, st) {
      LogService.error('Error sending WS message on current sink', e, st);
      _handleDisconnection();
      // Attempt once to reconnect and retry sending
      final connected = await connect();
      if (connected && _channel != null) {
        try {
          final jsonString = jsonEncode(message.toJson());
          LogService.ws(
              'Retrying WS Message send after successful reconnection',
              jsonString);
          _channel!.sink.add(jsonString);
          return true;
        } catch (retryErr) {
          LogService.error('Retry WS message send failed', retryErr);
        }
      }
      return false;
    }
  }

  void disconnect() {
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    LogService.ws('Disconnecting WebSocket');
    _channel?.sink.close();
    _channel = null;
  }
}
