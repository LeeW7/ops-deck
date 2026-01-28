import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preview_model.dart';

/// WebSocket error types for better error handling
enum WsErrorType {
  connectionFailed,
  connectionLost,
  timeout,
  invalidMessage,
  serverError,
  unknown,
}

/// Typed WebSocket exception
class WsException implements Exception {
  final WsErrorType type;
  final String message;
  final Object? originalError;

  WsException(this.type, this.message, [this.originalError]);

  @override
  String toString() => 'WsException($type): $message';

  /// User-friendly error message
  String get userMessage {
    switch (type) {
      case WsErrorType.connectionFailed:
        return 'Unable to connect to server';
      case WsErrorType.connectionLost:
        return 'Connection to server lost';
      case WsErrorType.timeout:
        return 'Connection timed out';
      case WsErrorType.invalidMessage:
        return 'Received invalid data from server';
      case WsErrorType.serverError:
        return 'Server error occurred';
      case WsErrorType.unknown:
        return 'An unexpected error occurred';
    }
  }
}

/// Service for connecting to job streaming WebSocket
class WebSocketService {
  static const String _baseUrlKey = 'server_base_url';
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentJobId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = false;

  final _messageController = StreamController<StreamMessage>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  final _errorController = StreamController<WsException>.broadcast();
  bool _isDisposed = false;

  /// Stream of messages from the WebSocket
  Stream<StreamMessage> get messages => _messageController.stream;

  /// Stream of connection state changes
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;

  /// Stream of errors (for UI to display)
  Stream<WsException> get errors => _errorController.stream;

  /// Current connection state
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  /// Current reconnect attempt count (for UI display)
  int get reconnectAttempts => _reconnectAttempts;

  /// Connect to a job's WebSocket stream
  Future<bool> connect(String jobId, {bool autoReconnect = true}) async {
    // Disconnect from any existing connection
    await disconnect();

    final wsUrl = await _getWebSocketUrl(jobId);
    if (wsUrl == null) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'Server URL not configured',
      );
      _emitError(error);
      _updateState(WsConnectionState.error);
      return false;
    }

    try {
      _updateState(WsConnectionState.connecting);
      _currentJobId = jobId;
      _shouldReconnect = autoReconnect;
      _reconnectAttempts = 0;

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
            print('[WebSocket] Connection closed for job $_currentJobId');
          }
          _updateState(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
      );

      _updateState(WsConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection
      return true;
    } on SocketException catch (e) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'Network error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } on WebSocketChannelException catch (e) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'WebSocket error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } on TimeoutException catch (e) {
      final error = WsException(
        WsErrorType.timeout,
        'Connection timed out',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } catch (e) {
      final error = WsException(
        WsErrorType.unknown,
        'Failed to connect: $e',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    }
  }

  void _handleConnectionError(dynamic error) {
    WsException wsError;

    if (error is SocketException) {
      wsError = WsException(
        WsErrorType.connectionLost,
        'Network connection lost: ${error.message}',
        error,
      );
    } else if (error is WebSocketChannelException) {
      wsError = WsException(
        WsErrorType.connectionLost,
        'WebSocket connection error: ${error.message}',
        error,
      );
    } else {
      wsError = WsException(
        WsErrorType.unknown,
        'Connection error: $error',
        error,
      );
    }

    if (kDebugMode) {
      print('[WebSocket] Error: ${wsError.message}');
    }
    _emitError(wsError);
    _updateState(WsConnectionState.error);
    _scheduleReconnect();
  }

  void _handleConnectionFailure(WsException error) {
    if (kDebugMode) {
      print('[WebSocket] ${error.message}');
    }
    _emitError(error);
    _updateState(WsConnectionState.error);
    _scheduleReconnect();
  }

  void _emitError(WsException error) {
    if (!_isDisposed) {
      _errorController.add(error);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _isDisposed || _currentJobId == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('[WebSocket] Max reconnect attempts reached ($_maxReconnectAttempts)');
      }
      _emitError(WsException(
        WsErrorType.connectionFailed,
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
      print('[WebSocket] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }

    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !_isDisposed && _currentJobId != null) {
        connect(_currentJobId!, autoReconnect: true);
      }
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _currentJobId = null;
    _reconnectAttempts = 0;
    _updateState(WsConnectionState.disconnected);
  }

  /// Send a message to the server (e.g., user input)
  void send(Map<String, dynamic> message) {
    if (_channel != null && _state == WsConnectionState.connected) {
      _channel!.sink.add(json.encode(message));
    }
  }

  /// Send ping to keep connection alive
  void ping() {
    send({'type': 'ping'});
  }

  void _handleMessage(dynamic data) {
    if (_isDisposed) return;
    try {
      final decoded = json.decode(data as String) as Map<String, dynamic>;
      final message = StreamMessage.fromJson(decoded);
      if (!_isDisposed) {
        _messageController.add(message);
      }
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('[WebSocket] Invalid JSON received: $e');
        print('[WebSocket] Raw data: ${data.toString().substring(0, (data.toString().length).clamp(0, 200))}...');
      }
      // Don't emit error for parse failures - just log them
    } on TypeError catch (e) {
      if (kDebugMode) {
        print('[WebSocket] Message type error: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebSocket] Failed to parse message: $e');
      }
    }
  }

  void _updateState(WsConnectionState newState) {
    _state = newState;
    if (!_isDisposed) {
      _connectionStateController.add(newState);
    }
  }

  Future<String?> _getWebSocketUrl(String jobId) async {
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

    return '$wsUrl/ws/jobs/$jobId';
  }

  /// Check if connected to a specific job
  bool isConnectedTo(String jobId) {
    return _state == WsConnectionState.connected && _currentJobId == jobId;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    _connectionStateController.close();
    _errorController.close();
  }
}

/// WebSocket connection state
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Message received from WebSocket
class StreamMessage {
  final String type;
  final String jobId;
  final DateTime timestamp;
  final StreamData? data;

  StreamMessage({
    required this.type,
    required this.jobId,
    required this.timestamp,
    this.data,
  });

  factory StreamMessage.fromJson(Map<String, dynamic> json) {
    StreamData? data;

    if (json['data'] != null) {
      final dataJson = json['data'] as Map<String, dynamic>;
      final dataType = dataJson['type'] as String?;
      final content = dataJson['content'];

      switch (dataType) {
        case 'text':
          data = StreamData.text(content as String);
          break;
        case 'status':
          data = StreamData.status(content as String);
          break;
        case 'tool':
          data = StreamData.tool(ToolUseData.fromJson(content as Map<String, dynamic>));
          break;
        case 'result':
          data = StreamData.result(ResultData.fromJson(content as Map<String, dynamic>));
          break;
        case 'error':
          data = StreamData.error(content as String);
          break;
      }
    }

    // Parse timestamp - Swift sends Unix timestamp as double (seconds since 1970)
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

    return StreamMessage(
      type: json['type'] as String? ?? 'unknown',
      jobId: json['jobId'] as String? ?? '',
      timestamp: timestamp,
      data: data,
    );
  }
}

/// Data payload types
sealed class StreamData {
  const StreamData();

  factory StreamData.text(String content) = TextData;
  factory StreamData.status(String status) = StatusData;
  factory StreamData.tool(ToolUseData tool) = ToolData;
  factory StreamData.result(ResultData result) = ResultDataWrapper;
  factory StreamData.error(String error) = ErrorData;
}

class TextData extends StreamData {
  final String content;
  const TextData(this.content);
}

class StatusData extends StreamData {
  final String status;
  const StatusData(this.status);
}

class ToolData extends StreamData {
  final ToolUseData tool;
  const ToolData(this.tool);
}

class ResultDataWrapper extends StreamData {
  final ResultData result;
  const ResultDataWrapper(this.result);
}

class ErrorData extends StreamData {
  final String error;
  const ErrorData(this.error);
}

/// Tool use data
class ToolUseData {
  final String toolName;
  final String? toolId;
  final String? input;

  ToolUseData({
    required this.toolName,
    this.toolId,
    this.input,
  });

  factory ToolUseData.fromJson(Map<String, dynamic> json) {
    return ToolUseData(
      toolName: json['toolName'] as String? ?? 'unknown',
      toolId: json['toolId'] as String?,
      input: json['input'] as String?,
    );
  }

  /// Returns a human-readable description of what this tool is doing
  String get displayText {
    if (input == null || input!.isEmpty) return toolName;

    try {
      final parsed = jsonDecode(input!) as Map<String, dynamic>;

      switch (toolName.toLowerCase()) {
        case 'read':
          final path = parsed['file_path'] as String?;
          if (path != null) {
            // Extract just the filename from the path
            final filename = path.split('/').last;
            return 'Reading $filename';
          }
          break;

        case 'edit':
          final path = parsed['file_path'] as String?;
          if (path != null) {
            final filename = path.split('/').last;
            final oldStr = parsed['old_string'] as String?;
            final newStr = parsed['new_string'] as String?;
            final oldLines = oldStr?.split('\n').length ?? 0;
            final newLines = newStr?.split('\n').length ?? 0;
            final diff = newLines - oldLines;
            final diffStr = diff >= 0 ? '+$diff' : '$diff';
            return 'Editing $filename ($diffStr lines)';
          }
          break;

        case 'write':
          final path = parsed['file_path'] as String?;
          if (path != null) {
            final filename = path.split('/').last;
            final content = parsed['content'] as String?;
            final lines = content?.split('\n').length ?? 0;
            return 'Writing $filename ($lines lines)';
          }
          break;

        case 'bash':
          final command = parsed['command'] as String?;
          final desc = parsed['description'] as String?;
          if (desc != null && desc.isNotEmpty) {
            return desc;
          }
          if (command != null) {
            // Truncate long commands
            return command.length > 60
                ? '${command.substring(0, 57)}...'
                : command;
          }
          break;

        case 'glob':
          final pattern = parsed['pattern'] as String?;
          if (pattern != null) {
            return 'Finding $pattern';
          }
          break;

        case 'grep':
          final pattern = parsed['pattern'] as String?;
          if (pattern != null) {
            return 'Searching for "$pattern"';
          }
          break;

        case 'task':
          final desc = parsed['description'] as String?;
          final agentType = parsed['subagent_type'] as String?;
          if (desc != null) {
            return desc;
          }
          if (agentType != null) {
            return 'Running $agentType agent';
          }
          break;

        case 'todowrite':
          return 'Updating task list';

        case 'webfetch':
          final url = parsed['url'] as String?;
          if (url != null) {
            final uri = Uri.tryParse(url);
            return 'Fetching ${uri?.host ?? url}';
          }
          break;

        case 'websearch':
          final query = parsed['query'] as String?;
          if (query != null) {
            return 'Searching: $query';
          }
          break;
      }
    } catch (_) {
      // If JSON parsing fails, return tool name
    }

    return toolName;
  }

  /// Returns true if this is an Edit or Write tool with viewable content
  bool get hasEditContent {
    final name = toolName.toLowerCase();
    return name == 'edit' || name == 'write';
  }

  /// Returns edit details for display (file path, old content, new content)
  EditDetails? get editDetails {
    if (input == null || input!.isEmpty) return null;

    try {
      final parsed = jsonDecode(input!) as Map<String, dynamic>;
      final name = toolName.toLowerCase();

      if (name == 'edit') {
        return EditDetails(
          filePath: parsed['file_path'] as String? ?? 'unknown',
          oldContent: parsed['old_string'] as String?,
          newContent: parsed['new_string'] as String?,
          isWrite: false,
        );
      } else if (name == 'write') {
        return EditDetails(
          filePath: parsed['file_path'] as String? ?? 'unknown',
          oldContent: null,
          newContent: parsed['content'] as String?,
          isWrite: true,
        );
      }
    } catch (_) {}

    return null;
  }
}

/// Details for an Edit or Write operation
class EditDetails {
  final String filePath;
  final String? oldContent;
  final String? newContent;
  final bool isWrite;

  EditDetails({
    required this.filePath,
    this.oldContent,
    this.newContent,
    required this.isWrite,
  });

  String get fileName => filePath.split('/').last;

  int get linesAdded {
    if (newContent == null) return 0;
    if (isWrite) return newContent!.split('\n').length;
    final oldLines = oldContent?.split('\n').length ?? 0;
    final newLines = newContent!.split('\n').length;
    return newLines > oldLines ? newLines - oldLines : 0;
  }

  int get linesRemoved {
    if (oldContent == null || isWrite) return 0;
    final oldLines = oldContent!.split('\n').length;
    final newLines = newContent?.split('\n').length ?? 0;
    return oldLines > newLines ? oldLines - newLines : 0;
  }
}

/// Result data with cost info
class ResultData {
  final String? sessionId;
  final double? totalCostUsd;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheReadTokens;
  final int? cacheCreationTokens;
  final double? duration;

  ResultData({
    this.sessionId,
    this.totalCostUsd,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
    this.cacheCreationTokens,
    this.duration,
  });

  factory ResultData.fromJson(Map<String, dynamic> json) {
    return ResultData(
      sessionId: json['sessionId'] as String?,
      totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble(),
      inputTokens: json['inputTokens'] as int?,
      outputTokens: json['outputTokens'] as int?,
      cacheReadTokens: json['cacheReadTokens'] as int?,
      cacheCreationTokens: json['cacheCreationTokens'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }
}

// ============================================================================
// Global Events WebSocket Service
// Connects to /ws/events for all job lifecycle updates
// ============================================================================

/// Service for receiving global job events via WebSocket
/// Connect once on app start to receive all job status updates
class GlobalEventsService {
  static const String _baseUrlKey = 'server_base_url';
  static const int _maxReconnectAttempts = 10; // More attempts for global service
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _eventController = StreamController<JobEvent>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  final _errorController = StreamController<WsException>.broadcast();
  bool _isDisposed = false;
  bool _shouldReconnect = true;

  /// Stream of job events from the server
  Stream<JobEvent> get events => _eventController.stream;

  /// Stream of connection state changes
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;

  /// Stream of errors (for UI display)
  Stream<WsException> get errors => _errorController.stream;

  /// Current connection state
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  /// Current reconnect attempt count (for UI display)
  int get reconnectAttempts => _reconnectAttempts;

  /// Connect to global events WebSocket
  Future<bool> connect() async {
    if (_state == WsConnectionState.connected || _state == WsConnectionState.connecting) {
      return true;
    }

    final wsUrl = await _getWebSocketUrl();
    if (wsUrl == null) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'Server URL not configured',
      );
      _emitError(error);
      _updateState(WsConnectionState.error);
      return false;
    }

    try {
      _updateState(WsConnectionState.connecting);
      _shouldReconnect = true;

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
            print('[GlobalEvents] Connection closed');
          }
          _updateState(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
      );

      // Start ping timer to keep connection alive
      _startPingTimer();

      _updateState(WsConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection
      if (kDebugMode) {
        print('[GlobalEvents] Connected to $wsUrl');
      }
      return true;
    } on SocketException catch (e) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'Network error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } on WebSocketChannelException catch (e) {
      final error = WsException(
        WsErrorType.connectionFailed,
        'WebSocket error: ${e.message}',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    } catch (e) {
      final error = WsException(
        WsErrorType.unknown,
        'Failed to connect: $e',
        e,
      );
      _handleConnectionFailure(error);
      return false;
    }
  }

  void _handleConnectionError(dynamic error) {
    WsException wsError;

    if (error is SocketException) {
      wsError = WsException(
        WsErrorType.connectionLost,
        'Network connection lost: ${error.message}',
        error,
      );
    } else if (error is WebSocketChannelException) {
      wsError = WsException(
        WsErrorType.connectionLost,
        'WebSocket connection error: ${error.message}',
        error,
      );
    } else {
      wsError = WsException(
        WsErrorType.unknown,
        'Connection error: $error',
        error,
      );
    }

    if (kDebugMode) {
      print('[GlobalEvents] Error: ${wsError.message}');
    }
    _emitError(wsError);
    _updateState(WsConnectionState.error);
    _scheduleReconnect();
  }

  void _handleConnectionFailure(WsException error) {
    if (kDebugMode) {
      print('[GlobalEvents] ${error.message}');
    }
    _emitError(error);
    _updateState(WsConnectionState.error);
    _scheduleReconnect();
  }

  void _emitError(WsException error) {
    if (!_isDisposed) {
      _errorController.add(error);
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectAttempts = 0;

    _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _updateState(WsConnectionState.disconnected);
  }

  /// Reset reconnection state and attempt to connect again
  /// Call this when the user manually triggers a refresh
  void resetAndReconnect() {
    _reconnectAttempts = 0;
    _shouldReconnect = true;
    connect();
  }

  void _handleMessage(dynamic data) {
    if (_isDisposed) return;
    try {
      final decoded = json.decode(data as String) as Map<String, dynamic>;

      // Skip connection/pong messages
      final type = decoded['type'] as String?;
      if (type == 'connected' || type == 'pong') {
        return;
      }

      final event = JobEvent.fromJson(decoded);
      if (!_isDisposed) {
        _eventController.add(event);
      }
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('[GlobalEvents] Invalid JSON received: $e');
      }
    } on TypeError catch (e) {
      if (kDebugMode) {
        print('[GlobalEvents] Message type error: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GlobalEvents] Failed to parse message: $e');
      }
    }
  }

  void _updateState(WsConnectionState newState) {
    _state = newState;
    if (!_isDisposed) {
      _connectionStateController.add(newState);
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _state == WsConnectionState.connected) {
        _channel!.sink.add('{"type":"ping"}');
      }
    });
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _isDisposed) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('[GlobalEvents] Max reconnect attempts reached ($_maxReconnectAttempts)');
      }
      _emitError(WsException(
        WsErrorType.connectionFailed,
        'Failed to reconnect after $_maxReconnectAttempts attempts. Pull down to retry.',
      ));
      // Reset attempts so user can manually trigger reconnect
      _reconnectAttempts = 0;
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s (capped at 60s)
    final delay = Duration(
      milliseconds: (_initialReconnectDelay.inMilliseconds *
          (1 << _reconnectAttempts)).clamp(0, _maxReconnectDelay.inMilliseconds),
    );

    _reconnectAttempts++;

    if (kDebugMode) {
      print('[GlobalEvents] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }

    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !_isDisposed) {
        connect();
      }
    });
  }

  Future<String?> _getWebSocketUrl() async {
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

    return '$wsUrl/ws/events';
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
    _connectionStateController.close();
    _errorController.close();
  }
}

/// Job lifecycle event from server
class JobEvent {
  final JobEventType type;
  final DateTime timestamp;
  final JobEventData job;

  JobEvent({
    required this.type,
    required this.timestamp,
    required this.job,
  });

  factory JobEvent.fromJson(Map<String, dynamic> json) {
    // Parse timestamp
    DateTime timestamp;
    if (json['timestamp'] != null) {
      final ts = json['timestamp'];
      if (ts is num) {
        timestamp = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
      } else if (ts is String) {
        timestamp = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    return JobEvent(
      type: JobEventType.fromString(json['type'] as String? ?? ''),
      timestamp: timestamp,
      job: JobEventData.fromJson(json['job'] as Map<String, dynamic>),
    );
  }
}

enum JobEventType {
  jobCreated,
  jobStatusChanged,
  jobCompleted,
  jobFailed,
  previewStatusChanged,
  testResultsUpdated,
  unknown;

  static JobEventType fromString(String value) {
    switch (value) {
      case 'jobCreated':
        return JobEventType.jobCreated;
      case 'jobStatusChanged':
        return JobEventType.jobStatusChanged;
      case 'jobCompleted':
        return JobEventType.jobCompleted;
      case 'jobFailed':
        return JobEventType.jobFailed;
      case 'previewStatusChanged':
        return JobEventType.previewStatusChanged;
      case 'testResultsUpdated':
        return JobEventType.testResultsUpdated;
      default:
        return JobEventType.unknown;
    }
  }
}

/// Minimal job data sent in events
class JobEventData {
  final String id;
  final String repo;
  final int issueNum;
  final String issueTitle;
  final String command;
  final String status;
  final JobCostData? cost;
  // Preview-related fields (for previewStatusChanged events)
  final PreviewDeployment? preview;
  final List<TestResult>? testResults;

  JobEventData({
    required this.id,
    required this.repo,
    required this.issueNum,
    required this.issueTitle,
    required this.command,
    required this.status,
    this.cost,
    this.preview,
    this.testResults,
  });

  factory JobEventData.fromJson(Map<String, dynamic> json) {
    return JobEventData(
      id: json['id'] as String? ?? '',
      repo: json['repo'] as String? ?? '',
      issueNum: json['issueNum'] as int? ?? json['issue_num'] as int? ?? 0,
      issueTitle: json['issueTitle'] as String? ?? json['issue_title'] as String? ?? '',
      command: json['command'] as String? ?? '',
      status: json['status'] as String? ?? '',
      cost: json['cost'] != null
          ? JobCostData.fromJson(json['cost'] as Map<String, dynamic>)
          : null,
      preview: json['preview'] != null
          ? PreviewDeployment.fromJson(json['preview'] as Map<String, dynamic>)
          : null,
      testResults: json['test_results'] != null || json['testResults'] != null
          ? ((json['test_results'] ?? json['testResults']) as List<dynamic>)
              .map((t) => TestResult.fromJson(t as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}

class JobCostData {
  final double totalUsd;
  final int inputTokens;
  final int outputTokens;

  JobCostData({
    required this.totalUsd,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory JobCostData.fromJson(Map<String, dynamic> json) {
    return JobCostData(
      totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0,
      inputTokens: json['inputTokens'] as int? ?? 0,
      outputTokens: json['outputTokens'] as int? ?? 0,
    );
  }
}
