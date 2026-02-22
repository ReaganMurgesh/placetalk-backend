import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:placetalk/core/config/api_config.dart';

/// Real-time Socket.io client for community chat.
///
/// Usage in a screen:
/// ```dart
/// final _socket = SocketService();
///
/// @override
/// void initState() {
///   super.initState();
///   _socket.connect();
///   _socket.joinCommunity(communityId, _onNewMessage);
/// }
///
/// @override
/// void dispose() {
///   _socket.leaveCommunity(communityId);
///   _socket.disconnect();
///   super.dispose();
/// }
/// ```
class SocketService {
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    if (isConnected) return;

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          // Start with polling (Render-safe), upgrade to websocket when possible
          .setTransports(['polling', 'websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) => print('🔌 Socket.io connected'));
    _socket!.onConnectError((e) => print('⚠️ Socket.io connect error: $e'));
    _socket!.onDisconnect((_) => print('🔌 Socket.io disconnected'));
    _socket!.connect();
  }

  /// Join a community chat room and register a callback for new messages.
  /// The [onMessage] callback receives the raw JSON map from the server.
  void joinCommunity(String communityId, void Function(Map<String, dynamic>) onMessage) {
    _socket?.emit('join_community', communityId);
    // Clear any previous listener before registering the new one
    _socket?.off('new_message');
    _socket?.on('new_message', (data) {
      try {
        if (data is Map) {
          onMessage(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('⚠️ Socket message parse error: $e');
      }
    });
  }

  /// Leave a community chat room and stop listening for messages.
  void leaveCommunity(String communityId) {
    _socket?.emit('leave_community', communityId);
    _socket?.off('new_message');
  }

  // ── 1.4: Creator footprint alerts ──────────────────────────────

  /// Join a personal user room so the backend can push creator_alert events.
  void listenForCreatorAlerts(
      String userId, void Function(Map<String, dynamic>) onAlert) {
    if (!isConnected) return;
    _socket?.emit('join_user_room', userId);
    _socket?.off('creator_alert');
    _socket?.on('creator_alert', (data) {
      try {
        if (data is Map) {
          onAlert(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        debugPrint('⚠️ creator_alert parse error: $e');
      }
    });
  }

  void stopCreatorAlerts() {
    _socket?.off('creator_alert');
  }

  /// Disconnect from the server entirely.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
