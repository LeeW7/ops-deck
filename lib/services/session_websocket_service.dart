import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Message types for session WebSocket events
enum SessionMessageType {
  connected,
  statusChange,
  assistantText,
  toolUse,
  result,
  error,
  userInput,
  unknown;

  static SessionMessageType fromString(String value) {
    switch (value) {
      case 'connected':
        return SessionMessageType.connected;
      case 'status_change':
      case 'statusChange':
        return SessionMessageType.statusChange;
      case 'assistant_text':
      case 'assistantText':
        return SessionMessageType.assistantText;
      case 'tool_use':
      case 'toolUse':
        return SessionMessageType.toolUse;
      case 'result':
        return SessionMessageType.result;
      case 'error':
        return SessionMessageType.error;
      case 'user_input':
      case 'userInput':
        return SessionMessageType.userInput;
      default:
        return SessionMessageType.unknown;
    }
  }
}

/// Represents a streamed message from a session WebSocket
class SessionStreamMessage {
  final SessionMessageType type;
  final String? content;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SessionStreamMessage({
    required this.type,
    this.content,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SessionStreamMessage.fromJson(Map<String, dynamic> json) {
    // Parse timestamp
    DateTime timestamp;
    if (json['timestamp'] != null) {
      final ts = json['timestamp'];
      if (ts is num) {
        // Unix timestamp (seconds)
        timestamp = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
      } else if (ts is String) {
        // ISO string fallback
        timestamp = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    return SessionStreamMessage(
      type: SessionMessageType.fromString(json['type'] as String? ?? ''),
      content: json['content'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      timestamp: timestamp,
    );
  }

  /// Check if this message has tool information
  bool get hasToolInfo => type == SessionMessageType.toolUse && data != null;

  /// Get tool name if this is a tool use message
  String? get toolName => data?['toolName'] as String?;

  /// Get tool input if this is a tool use message
  String? get toolInput => data?['input'] as String?;

  /// Check if this message has cost information
  bool get hasCostInfo => type == SessionMessageType.result && data != null;

  /// Get total cost in USD if available
  double? get totalCostUsd => (data?['totalCostUsd'] as num?)?.toDouble();

  /// Get input tokens if available
  int? get inputTokens => data?['inputTokens'] as int?;

  /// Get output tokens if available
  int? get outputTokens => data?['outputTokens'] as int?;

  @override
  String toString() => 'SessionStreamMessage($type, content: $content)';
}

/// Connection state for the session WebSocket
enum SessionConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// WebSocket error types for session connections
enum SessionWsErrorType {
  connectionFailed,
  connectionLost,
  timeout,
  invalidMessage,
  serverError,
  unknown,
}

/// Typed WebSocket exception for session connections
class SessionWsException implements Exception {
  final SessionWsErrorType type;
  final String message;
  final Object? originalError;

  SessionWsException(this.type, this.message, [this.originalError]);

  @override
  String toString() => 'SessionWsException($type): $message';

  /// User-friendly error message
  String get userMessage {
    switch (type) {
      case SessionWsErrorType.connectionFailed:
        return 'Unable to connect to session';
      case SessionWsErrorType.connectionLost:
        return 'Connection to session lost';
      case SessionWsErrorType.timeout:
        return 'Connection timed out';
      case SessionWsErrorType.invalidMessage:
        return 'Received invalid data from server';
      case SessionWsErrorType.serverError:
        return 'Server error occurred';
      case SessionWsErrorType.unknown:
        return 'An unexpected error occurred';
    }
  }
}

/// Service for connecting to session streaming WebSocket
/// Connects to /ws/sessions/{sessionId} for real-time session events
class SessionWebSocketService {
  static const String _baseUrlKey = 'server_base_url';
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _pingInterval = Duration(seconds: 30);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentSessionId;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = false;

  final _messageController = StreamController<SessionStreamMessage>.broadcast();
  final _connectionStateController = StreamController<SessionConnectionState>.broadcast();
  final _errorController = StreamController<SessionWsException>.broadcast();
  bool _isDisposed = false;

  /// Stream of messages from the WebSocket
  Stream<SessionStreamMessage> get messageStream => _messageController.stream;

  /// Stream of connection state changes
  Stream<SessionConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Stream of errors (for UI to display)
  Stream<SessionWsException> get errors => _errorController.stream;

  /// Current connection state
  SessionConnectionState _state = SessionConnectionState.disconnected;
  SessionConnectionState get state => _state;

  /// Current session ID
  String? get currentSessionId => _currentSessionId;

  /// Current reconnect attempt count (for UI display)
  int get reconnectAttempts => _reconnectAttempts;

  /// Connect to a session's WebSocket stream
  Future<bool> connect(String sessionId, {bool autoReconnect = true}) async {
    // Disconnect from any existing connection
    await disconnect();

    final wsUrl = await _getWebSocketUrl(sessionId);
    if (wsUrl == null) {
      final error = SessionWsException(
        SessionWsErrorType.connectionFailed,
        'Server URL not configured',
      );
      _emitError(error);
      _updateState(SessionConnectionState.error);
      return false;
    }

    try {
      _updateState(SessionConnectionState.connecting);
      _currentSessionId = sessionId;
      _shouldReconnect = autoReconnect;
      _reconnectAttempts = 0;

      if (kDebugMode) {
        print('[SessionWS] Connecting to $wsUrl');
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          _handleConnectionError(error);
        },
        onDone: () {
          if (kDebugMode) {
            print('[SessionWS] Connection closed for session $_currentSessionId');
          }
          _stopPingTimer();
          _updateState(SessionConnectionState.disconnected);
          _scheduleReconnect();
        },
      );

      // Start ping timer to keep connection alive
      _startPingTimer();

      _updateState(SessionConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection

      if (kDebugMode) {
        print('[SessionWS] Connected to session $sessionId');
      }

      return true;
    } on SocketException catch (e) {
      final error = SessionWsException(
        SessionWsErrorType.connectionFailed,
        'Network error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } on WebSocketChannelException catch (e) {
      final error = SessionWsException(
        SessionWsErrorType.connectionFailed,
        'WebSocket error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } on TimeoutException catch (e) {
      final error = SessionWsException(
        SessionWsErrorType.timeout,
        'Connection timed out',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } catch (e) {
      final error = SessionWsException(
        SessionWsErrorType.unknown,
        'Failed to connect: $e',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    }
  }

  void _handleConnectionError(dynamic error) {
    SessionWsException wsError;

    if (error is SocketException) {
      wsError = SessionWsException(
        SessionWsErrorType.connectionLost,
        'Network connection lost: ${error.message}',
        error,
      );
    } else if (error is WebSocketChannelException) {
      wsError = SessionWsException(
        SessionWsErrorType.connectionLost,
        'WebSocket connection error: ${error.message}',
        error,
      );
    } else {
      wsError = SessionWsException(
        SessionWsErrorType.unknown,
        'Connection error: $error',
        error,
      );
    }

    if (kDebugMode) {
      print('[SessionWS] Error: ${wsError.message}');
    }
    _emitError(wsError);
    _stopPingTimer();
    _updateState(SessionConnectionState.error);
    _scheduleReconnect();
  }

  void _handleConnectionFailure(SessionWsException error) {
    if (kDebugMode) {
      print('[SessionWS] ${error.message}');
    }
    _emitError(error);
    _stopPingTimer();
    _updateState(SessionConnectionState.error);
    _scheduleReconnect();
  }

  void _emitError(SessionWsException error) {
    if (!_isDisposed) {
      _errorController.add(error);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _isDisposed || _currentSessionId == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('[SessionWS] Max reconnect attempts reached ($_maxReconnectAttempts)');
      }
      _emitError(SessionWsException(
        SessionWsErrorType.connectionFailed,
        'Failed to reconnect after $_maxReconnectAttempts attempts',
      ));
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
    final delay = Duration(
      milliseconds: (_initialReconnectDelay.inMilliseconds *
          (1 << _reconnectAttempts)).clamp(0, _maxReconnectDelay.inMilliseconds),
    );

    _reconnectAttempts++;

    if (kDebugMode) {
      print('[SessionWS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }

    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !_isDisposed && _currentSessionId != null) {
        connect(_currentSessionId!, autoReconnect: true);
      }
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPingTimer();

    _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _currentSessionId = null;
    _reconnectAttempts = 0;
    _updateState(SessionConnectionState.disconnected);
  }

  /// Send a user message to the session
  void send(String content) {
    if (_channel != null && _state == SessionConnectionState.connected) {
      final message = json.encode({
        'type': 'user_input',
        'content': content,
      });
      _channel!.sink.add(message);
      if (kDebugMode) {
        final preview = content.length > 50 ? '${content.substring(0, 50)}...' : content;
        print('[SessionWS] Sent user input: $preview');
      }
    } else {
      if (kDebugMode) {
        print('[SessionWS] Cannot send - not connected (state: $_state)');
      }
    }
  }

  /// Send a raw JSON message
  void sendRaw(Map<String, dynamic> message) {
    if (_channel != null && _state == SessionConnectionState.connected) {
      _channel!.sink.add(json.encode(message));
    }
  }

  /// Send ping to keep connection alive
  void _ping() {
    if (_channel != null && _state == SessionConnectionState.connected) {
      _channel!.sink.add('{"type":"ping"}');
    }
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _ping();
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _handleMessage(dynamic data) {
    if (_isDisposed) return;
    try {
      final decoded = json.decode(data as String) as Map<String, dynamic>;

      // Skip pong messages
      final type = decoded['type'] as String?;
      if (type == 'pong') {
        return;
      }

      final message = SessionStreamMessage.fromJson(decoded);
      if (!_isDisposed) {
        _messageController.add(message);
      }

      if (kDebugMode) {
        final contentPreview = message.content != null
            ? (message.content!.length > 50
                ? '${message.content!.substring(0, 50)}...'
                : message.content)
            : null;
        print('[SessionWS] Received: ${message.type} - $contentPreview');
      }
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('[SessionWS] Invalid JSON received: $e');
        final dataStr = data.toString();
        final preview = dataStr.length > 200 ? '${dataStr.substring(0, 200)}...' : dataStr;
        print('[SessionWS] Raw data: $preview');
      }
      // Don't emit error for parse failures - just log them
    } on TypeError catch (e) {
      if (kDebugMode) {
        print('[SessionWS] Message type error: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SessionWS] Failed to parse message: $e');
      }
    }
  }

  void _updateState(SessionConnectionState newState) {
    _state = newState;
    if (!_isDisposed) {
      _connectionStateController.add(newState);
    }
  }

  Future<String?> _getWebSocketUrl(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey);

    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }

    // Convert http(s) to ws(s)
    String wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // Remove trailing slash
    if (wsUrl.endsWith('/')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 1);
    }

    return '$wsUrl/ws/sessions/$sessionId';
  }

  /// Check if connected to a specific session
  bool isConnectedTo(String sessionId) {
    return _state == SessionConnectionState.connected && _currentSessionId == sessionId;
  }

  /// Reset reconnection state and attempt to connect again
  /// Call this when the user manually triggers a reconnect
  void resetAndReconnect() {
    if (_currentSessionId != null) {
      _reconnectAttempts = 0;
      _shouldReconnect = true;
      connect(_currentSessionId!, autoReconnect: true);
    }
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    _connectionStateController.close();
    _errorController.close();
  }
}
