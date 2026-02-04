/// Status of a quick session
enum SessionStatus {
  idle,
  running,
  failed,
  expired;

  static SessionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'idle':
        return SessionStatus.idle;
      case 'running':
        return SessionStatus.running;
      case 'failed':
        return SessionStatus.failed;
      case 'expired':
        return SessionStatus.expired;
      default:
        return SessionStatus.idle;
    }
  }

  String get displayName {
    switch (this) {
      case SessionStatus.idle:
        return 'Idle';
      case SessionStatus.running:
        return 'Running';
      case SessionStatus.failed:
        return 'Failed';
      case SessionStatus.expired:
        return 'Expired';
    }
  }
}

/// Model for a quick Claude Code session
/// Represents an ephemeral session for ad-hoc work on a repository
class QuickSession {
  final String id;
  final String repo;
  final SessionStatus status;
  final String? worktreePath;
  final String? claudeSessionId;
  final DateTime createdAt;
  final DateTime lastActivity;
  final int messageCount;
  final double totalCostUsd;

  const QuickSession({
    required this.id,
    required this.repo,
    required this.status,
    this.worktreePath,
    this.claudeSessionId,
    required this.createdAt,
    required this.lastActivity,
    required this.messageCount,
    required this.totalCostUsd,
  });

  factory QuickSession.fromJson(Map<String, dynamic> json) {
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

    return QuickSession(
      id: safeString(json['id']) ?? '',
      repo: safeString(json['repo']) ?? '',
      status: SessionStatus.fromString(safeString(json['status']) ?? 'idle'),
      worktreePath: safeString(json['worktree_path']),
      claudeSessionId: safeString(json['claude_session_id']),
      createdAt: _parseDateTime(json['created_at']),
      lastActivity: _parseDateTime(json['last_activity']),
      messageCount: safeNum(json['message_count'])?.toInt() ?? 0,
      totalCostUsd: safeNum(json['total_cost_usd'])?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'repo': repo,
      'status': status.name,
      'worktree_path': worktreePath,
      'claude_session_id': claudeSessionId,
      'created_at': createdAt.toIso8601String(),
      'last_activity': lastActivity.toIso8601String(),
      'message_count': messageCount,
      'total_cost_usd': totalCostUsd,
    };
  }

  QuickSession copyWith({
    String? id,
    String? repo,
    SessionStatus? status,
    String? worktreePath,
    String? claudeSessionId,
    DateTime? createdAt,
    DateTime? lastActivity,
    int? messageCount,
    double? totalCostUsd,
  }) {
    return QuickSession(
      id: id ?? this.id,
      repo: repo ?? this.repo,
      status: status ?? this.status,
      worktreePath: worktreePath ?? this.worktreePath,
      claudeSessionId: claudeSessionId ?? this.claudeSessionId,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      messageCount: messageCount ?? this.messageCount,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  /// Formatted cost string
  String get formattedCost => '\$${totalCostUsd.toStringAsFixed(4)}';

  /// Whether this session can be resumed
  bool get canResume => claudeSessionId != null && status != SessionStatus.expired;

  /// Whether this session is currently active
  bool get isActive => status == SessionStatus.running;
}
