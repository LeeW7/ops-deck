import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for connecting to job streaming WebSocket
class WebSocketService {
  static const String _baseUrlKey = 'server_base_url';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentJobId;

  final _messageController = StreamController<StreamMessage>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  bool _isDisposed = false;

  /// Stream of messages from the WebSocket
  Stream<StreamMessage> get messages => _messageController.stream;

  /// Stream of connection state changes
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;

  /// Current connection state
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  /// Connect to a job's WebSocket stream
  Future<bool> connect(String jobId) async {
    // Disconnect from any existing connection
    await disconnect();

    final wsUrl = await _getWebSocketUrl(jobId);
    if (wsUrl == null) {
      _updateState(WsConnectionState.error);
      return false;
    }

    try {
      _updateState(WsConnectionState.connecting);
      _currentJobId = jobId;

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          if (kDebugMode) {
            print('[WebSocket] Error: $error');
          }
          _updateState(WsConnectionState.error);
        },
        onDone: () {
          if (kDebugMode) {
            print('[WebSocket] Connection closed');
          }
          _updateState(WsConnectionState.disconnected);
        },
      );

      _updateState(WsConnectionState.connected);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[WebSocket] Failed to connect: $e');
      }
      _updateState(WsConnectionState.error);
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _currentJobId = null;
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

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final _eventController = StreamController<JobEvent>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  bool _isDisposed = false;
  bool _shouldReconnect = true;

  /// Stream of job events from the server
  Stream<JobEvent> get events => _eventController.stream;

  /// Stream of connection state changes
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;

  /// Current connection state
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  /// Connect to global events WebSocket
  Future<bool> connect() async {
    if (_state == WsConnectionState.connected || _state == WsConnectionState.connecting) {
      return true;
    }

    final wsUrl = await _getWebSocketUrl();
    if (wsUrl == null) {
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
          if (kDebugMode) {
            print('[GlobalEvents] Error: $error');
          }
          _updateState(WsConnectionState.error);
          _scheduleReconnect();
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
      if (kDebugMode) {
        print('[GlobalEvents] Connected to $wsUrl');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[GlobalEvents] Failed to connect: $e');
      }
      _updateState(WsConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;

    _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _updateState(WsConnectionState.disconnected);
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

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_shouldReconnect && !_isDisposed) {
        if (kDebugMode) {
          print('[GlobalEvents] Attempting reconnect...');
        }
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

  JobEventData({
    required this.id,
    required this.repo,
    required this.issueNum,
    required this.issueTitle,
    required this.command,
    required this.status,
    this.cost,
  });

  factory JobEventData.fromJson(Map<String, dynamic> json) {
    return JobEventData(
      id: json['id'] as String? ?? '',
      repo: json['repo'] as String? ?? '',
      issueNum: json['issueNum'] as int? ?? 0,
      issueTitle: json['issueTitle'] as String? ?? '',
      command: json['command'] as String? ?? '',
      status: json['status'] as String? ?? '',
      cost: json['cost'] != null
          ? JobCostData.fromJson(json['cost'] as Map<String, dynamic>)
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
