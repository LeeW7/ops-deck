/// Role of a message in a conversation
enum MessageRole {
  user,
  assistant,
  system,
  tool;

  static MessageRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'tool':
      case 'tool_result':
        return MessageRole.tool;
      default:
        return MessageRole.user;
    }
  }

  String get displayName {
    switch (this) {
      case MessageRole.user:
        return 'User';
      case MessageRole.assistant:
        return 'Assistant';
      case MessageRole.system:
        return 'System';
      case MessageRole.tool:
        return 'Tool';
    }
  }
}

/// A message in a quick chat session
class QuickMessage {
  final String id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final double? costUsd;
  final String? toolName;
  final String? toolInput;

  const QuickMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.costUsd,
    this.toolName,
    this.toolInput,
  });

  factory QuickMessage.fromJson(Map<String, dynamic> json) {
    // Helper to safely cast to String with type check
    String? safeString(dynamic value) {
      if (value is String) return value;
      return null;
    }

    // Helper to safely cast to num with type check
    num? safeNum(dynamic value) {
      if (value is num) return value;
      return null;
    }

    return QuickMessage(
      id: safeString(json['id']) ?? '',
      sessionId: safeString(json['session_id']) ?? '',
      role: MessageRole.fromString(safeString(json['role']) ?? 'user'),
      content: safeString(json['content']) ?? '',
      timestamp: _parseDateTime(json['timestamp']),
      costUsd: safeNum(json['cost_usd'])?.toDouble(),
      toolName: safeString(json['tool_name']),
      toolInput: safeString(json['tool_input']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (costUsd != null) 'cost_usd': costUsd,
      if (toolName != null) 'tool_name': toolName,
      if (toolInput != null) 'tool_input': toolInput,
    };
  }

  QuickMessage copyWith({
    String? id,
    String? sessionId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    double? costUsd,
    String? toolName,
    String? toolInput,
  }) {
    return QuickMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      costUsd: costUsd ?? this.costUsd,
      toolName: toolName ?? this.toolName,
      toolInput: toolInput ?? this.toolInput,
    );
  }
}
