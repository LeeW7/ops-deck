import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/session_cache_service.dart';
import '../services/session_websocket_service.dart';

/// Provider for Quick Session chat functionality
/// Manages session list, current session, messages, and WebSocket streaming
class QuickSessionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SessionCacheService _cacheService = SessionCacheService();
  SessionWebSocketService? _wsService;

  // Private state
  List<QuickSession> _sessions = [];
  QuickSession? _currentSession;
  List<QuickMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isStreaming = false;
  String _streamingContent = '';
  String? _selectedRepo;

  // WebSocket subscriptions
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _errorSubscription;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get sessions filtered by selected repo if set
  List<QuickSession> get sessions {
    if (_selectedRepo == null) {
      return List.unmodifiable(_sessions);
    }
    return List.unmodifiable(
      _sessions.where((s) => s.repo == _selectedRepo).toList(),
    );
  }

  /// Get the currently selected/loaded session
  QuickSession? get currentSession => _currentSession;

  /// Get messages for the current session
  List<QuickMessage> get messages => List.unmodifiable(_messages);

  /// Whether the provider is loading data
  bool get isLoading => _isLoading;

  /// Current error message if any
  String? get error => _error;

  /// Whether we are waiting for Claude response (streaming)
  bool get isStreaming => _isStreaming;

  /// Accumulated text content while streaming
  String get streamingContent => _streamingContent;

  /// Currently selected repo filter
  String? get selectedRepo => _selectedRepo;

  /// Get distinct repos from all sessions
  List<String> get availableRepos {
    final repos = _sessions.map((s) => s.repo).toSet().toList();
    repos.sort();
    return repos;
  }

  /// Whether WebSocket is currently connected
  bool get isWebSocketConnected =>
      _wsService?.state == SessionConnectionState.connected;

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize the provider - load cached sessions and cleanup old ones
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[QuickSessionProvider] Initializing...');
    }

    try {
      // Load cached sessions first for instant UI
      final cachedSessions = await _cacheService.getAllSessions();
      if (cachedSessions.isNotEmpty) {
        _sessions = cachedSessions;
        if (kDebugMode) {
          print('[QuickSessionProvider] Loaded ${cachedSessions.length} sessions from cache');
        }
        notifyListeners();
      }

      // Cleanup old sessions in background
      await _cleanupOldSessions();

      // Fetch fresh data from API
      await fetchSessions();
    } catch (e) {
      if (kDebugMode) {
        print('[QuickSessionProvider] Initialize error: $e');
      }
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Cleanup old sessions based on age and count limits
  Future<void> _cleanupOldSessions() async {
    try {
      final deleted = await _cacheService.deleteOldSessions(
        maxAge: const Duration(hours: 24),
        maxPerRepo: 10,
      );
      if (deleted > 0 && kDebugMode) {
        final remaining = await _cacheService.getSessionCount();
        print('[QuickSessionProvider] Cleaned up $deleted old sessions ($remaining remaining)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[QuickSessionProvider] Cleanup error: $e');
      }
    }
  }

  // ============================================================================
  // Session Management
  // ============================================================================

  /// Fetch sessions from API and update cache
  Future<void> fetchSessions() async {
    final wasLoading = _isLoading;
    _isLoading = _sessions.isEmpty;
    if (_isLoading && !wasLoading) notifyListeners();

    try {
      final newSessions = await _apiService.getSessions();

      // Sort by last activity (most recent first)
      newSessions.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      // Save to cache
      await _cacheService.saveSessions(newSessions);

      _sessions = newSessions;
      _isLoading = false;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('[QuickSessionProvider] Fetched ${newSessions.length} sessions');
      }
    } catch (e) {
      _isLoading = false;

      // Handle 404 (endpoint not found) gracefully - server may not have
      // Quick Tasks implemented yet, or there are simply no sessions
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('not found') || errorStr.contains('404')) {
        // Not an error - just no sessions or endpoint not implemented
        _error = null;
        if (kDebugMode) {
          print('[QuickSessionProvider] Sessions endpoint not available (server may need Quick Tasks feature)');
        }
      } else {
        _error = _extractErrorMessage(e);
        if (kDebugMode) {
          print('[QuickSessionProvider] Fetch error: $_error');
        }
      }
      notifyListeners();
    }
  }

  /// Create a new session for a repository
  Future<QuickSession?> createSession(String repo) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _apiService.createSession(repo);

      // Add to local list and cache
      _sessions.insert(0, session);
      await _cacheService.saveSession(session);

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('[QuickSessionProvider] Created session: ${session.id}');
      }

      return session;
    } catch (e) {
      _isLoading = false;

      // Provide helpful error for missing server endpoint
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('not found') || errorStr.contains('404')) {
        _error = 'Quick Tasks requires server update. The /sessions endpoint is not available.';
      } else {
        _error = _extractErrorMessage(e);
      }

      if (kDebugMode) {
        print('[QuickSessionProvider] Create session error: $_error');
      }
      notifyListeners();
      return null;
    }
  }

  /// Load a session with its messages and connect WebSocket
  Future<void> loadSession(String id) async {
    if (kDebugMode) {
      print('[QuickSessionProvider] Loading session: $id');
    }

    _isLoading = true;
    _error = null;
    _messages = [];
    _streamingContent = '';
    _isStreaming = false;
    notifyListeners();

    try {
      // Disconnect from any existing WebSocket
      await _disconnectWebSocket();

      // Fetch session details from API
      final session = await _apiService.getSession(id);
      _currentSession = session;

      // Load messages from cache first
      final cachedMessages = await _cacheService.getMessagesForSession(id);
      if (cachedMessages.isNotEmpty) {
        _messages = cachedMessages;
        notifyListeners();
      }

      // Connect WebSocket for real-time streaming
      await _connectWebSocket(id);

      // Update cache with session
      await _cacheService.saveSession(session);

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('[QuickSessionProvider] Loaded session with ${_messages.length} messages');
      }
    } catch (e) {
      _isLoading = false;
      _error = _extractErrorMessage(e);
      if (kDebugMode) {
        print('[QuickSessionProvider] Load session error: $_error');
      }
      notifyListeners();
    }
  }

  /// Send a message in the current session
  Future<void> sendMessage(String content) async {
    if (_currentSession == null) {
      _error = 'No session selected';
      notifyListeners();
      return;
    }

    if (content.trim().isEmpty) {
      return;
    }

    // Add user message to list immediately for responsive UI
    final userMessage = QuickMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSession!.id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);

    // Start streaming state
    _isStreaming = true;
    _streamingContent = '';
    _error = null;
    notifyListeners();

    try {
      // Send via WebSocket if connected, otherwise use API
      if (_wsService?.state == SessionConnectionState.connected) {
        _wsService!.send(content);
        // WebSocket will handle the response via streaming
      } else {
        // Fallback to HTTP API when WebSocket disconnected.
        // NOTE: The HTTP API triggers Claude execution server-side but the
        // assistant response streams via WebSocket. Without an active WebSocket
        // connection, we won't receive the response in real-time. The message
        // will be saved server-side and can be retrieved when reconnecting.
        await _apiService.sendSessionMessage(
          _currentSession!.id,
          content,
        );

        // Since WebSocket is disconnected, we can't receive the streaming response.
        // The user message is saved; assistant response will appear on reconnect.
        _isStreaming = false;
        _streamingContent = '';
        _error = 'Message sent but response unavailable - WebSocket disconnected. Reconnect to see response.';
        notifyListeners();
      }

      // Save user message to cache
      await _cacheService.saveMessage(userMessage);
    } catch (e) {
      _isStreaming = false;
      _streamingContent = '';
      _error = _extractErrorMessage(e);
      if (kDebugMode) {
        print('[QuickSessionProvider] Send message error: $_error');
      }
      notifyListeners();
    }
  }

  /// Delete a session
  Future<bool> deleteSession(String id) async {
    try {
      // Delete from API
      await _apiService.deleteSession(id);

      // Delete from local cache
      await _cacheService.deleteSession(id);

      // Remove from local list
      _sessions.removeWhere((s) => s.id == id);

      // Clear current session if it was deleted
      if (_currentSession?.id == id) {
        _currentSession = null;
        _messages = [];
        await _disconnectWebSocket();
      }

      notifyListeners();

      if (kDebugMode) {
        print('[QuickSessionProvider] Deleted session: $id');
      }

      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      if (kDebugMode) {
        print('[QuickSessionProvider] Delete session error: $_error');
      }
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // Filtering
  // ============================================================================

  /// Set the selected repo filter
  void setSelectedRepo(String? repo) {
    if (_selectedRepo != repo) {
      _selectedRepo = repo;
      notifyListeners();
    }
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  /// Clear the current error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(Object e) {
    if (e is ApiException) {
      return e.userMessage;
    }
    return e.toString();
  }

  // ============================================================================
  // WebSocket Management
  // ============================================================================

  /// Connect to WebSocket for a session
  Future<void> _connectWebSocket(String sessionId) async {
    _wsService = SessionWebSocketService();

    // Listen for messages
    _messageSubscription = _wsService!.messageStream.listen(_handleWebSocketMessage);

    // Listen for connection state changes
    _connectionSubscription = _wsService!.connectionStateStream.listen((state) {
      if (kDebugMode) {
        print('[QuickSessionProvider] WebSocket state: $state');
      }
      notifyListeners();
    });

    // Listen for errors
    _errorSubscription = _wsService!.errors.listen((error) {
      if (kDebugMode) {
        print('[QuickSessionProvider] WebSocket error: ${error.userMessage}');
      }
      // Only set error if we were actively streaming
      if (_isStreaming) {
        _error = error.userMessage;
        _isStreaming = false;
        notifyListeners();
      }
    });

    // Connect
    await _wsService!.connect(sessionId);
  }

  /// Disconnect from WebSocket
  Future<void> _disconnectWebSocket() async {
    _messageSubscription?.cancel();
    _messageSubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _errorSubscription?.cancel();
    _errorSubscription = null;

    _wsService?.dispose();
    _wsService = null;
  }

  /// Handle incoming WebSocket message
  void _handleWebSocketMessage(SessionStreamMessage message) {
    switch (message.type) {
      case SessionMessageType.assistantText:
        // Accumulate streaming text
        if (message.content != null) {
          _streamingContent += message.content!;
          notifyListeners();
        }
        break;

      case SessionMessageType.result:
        // Streaming complete - create final message
        if (_streamingContent.isNotEmpty || message.content != null) {
          final assistantMessage = QuickMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: _currentSession?.id ?? '',
            role: MessageRole.assistant,
            content: _streamingContent.isNotEmpty
                ? _streamingContent
                : (message.content ?? ''),
            timestamp: message.timestamp,
            costUsd: message.totalCostUsd,
          );
          _messages.add(assistantMessage);
          _cacheService.saveMessage(assistantMessage);
        }

        // Update session stats if available
        if (_currentSession != null && message.data != null) {
          _updateSessionFromResult(message);
        }

        _isStreaming = false;
        _streamingContent = '';
        notifyListeners();
        break;

      case SessionMessageType.statusChange:
        // Handle session status changes
        if (message.data != null && _currentSession != null) {
          final newStatus = message.data!['status'] as String?;
          if (newStatus != null) {
            _currentSession = _currentSession!.copyWith(
              status: SessionStatus.fromString(newStatus),
            );
            _cacheService.saveSession(_currentSession!);
            notifyListeners();
          }
        }
        break;

      case SessionMessageType.toolUse:
        // Handle tool use events (for displaying in UI if needed)
        if (kDebugMode) {
          print('[QuickSessionProvider] Tool use: ${message.toolName}');
        }
        break;

      case SessionMessageType.error:
        _error = message.content ?? 'An error occurred';
        _isStreaming = false;
        _streamingContent = '';
        notifyListeners();
        break;

      case SessionMessageType.connected:
        if (kDebugMode) {
          print('[QuickSessionProvider] WebSocket connected event received');
        }
        break;

      case SessionMessageType.userInput:
      case SessionMessageType.unknown:
        // Ignore or log unknown message types
        if (kDebugMode) {
          print('[QuickSessionProvider] Unhandled message type: ${message.type}');
        }
        break;
    }
  }

  /// Update current session stats from a result message
  void _updateSessionFromResult(SessionStreamMessage message) {
    if (_currentSession == null || message.data == null) return;

    final data = message.data!;
    final totalCost = (data['totalCostUsd'] as num?)?.toDouble();
    final messageCount = data['messageCount'] as int?;

    if (totalCost != null || messageCount != null) {
      _currentSession = _currentSession!.copyWith(
        totalCostUsd: totalCost ?? _currentSession!.totalCostUsd,
        messageCount: messageCount ?? _currentSession!.messageCount,
        lastActivity: DateTime.now(),
      );

      // Update in session list
      final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
      if (index >= 0) {
        _sessions[index] = _currentSession!;
      }

      _cacheService.saveSession(_currentSession!);
    }
  }

  // ============================================================================
  // Lifecycle
  // ============================================================================

  @override
  void dispose() {
    _disconnectWebSocket();
    _cacheService.close();
    super.dispose();
  }
}
