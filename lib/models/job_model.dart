import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus { running, failed, pending, completed, waitingApproval, rejected, interrupted, approvedResume, blocked, unknown }

/// A decision made by Claude during job execution
class JobDecision {
  final String id;
  final String action;
  final String reasoning;
  final List<String>? alternatives;
  final String? category;
  final DateTime timestamp;

  JobDecision({
    required this.id,
    required this.action,
    required this.reasoning,
    this.alternatives,
    this.category,
    required this.timestamp,
  });

  factory JobDecision.fromJson(Map<String, dynamic> json) {
    return JobDecision(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      alternatives: (json['alternatives'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      category: json['category'] as String?,
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  /// Get an icon name based on category
  String get categoryIcon {
    switch (category?.toLowerCase()) {
      case 'architecture':
        return 'architecture';
      case 'library':
        return 'library';
      case 'pattern':
        return 'pattern';
      case 'storage':
        return 'storage';
      case 'api':
        return 'api';
      case 'testing':
        return 'testing';
      default:
        return 'other';
    }
  }
}

/// Confidence assessment for a job's implementation
class JobConfidence {
  final double score;
  final String assessment; // HIGH, MEDIUM, LOW
  final String reasoning;
  final String? risks;

  JobConfidence({
    required this.score,
    required this.assessment,
    required this.reasoning,
    this.risks,
  });

  factory JobConfidence.fromJson(Map<String, dynamic> json) {
    return JobConfidence(
      score: _parseScore(json['score']),
      assessment: json['assessment'] as String? ?? 'MEDIUM',
      reasoning: json['reasoning'] as String? ?? '',
      risks: json['risks'] as String?,
    );
  }

  static double _parseScore(dynamic value) {
    if (value == null) return 0.5;
    if (value is double) return value.clamp(0.0, 1.0);
    if (value is int) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) return double.tryParse(value)?.clamp(0.0, 1.0) ?? 0.5;
    return 0.5;
  }

  /// Get color based on confidence level
  int get colorValue {
    if (score >= 0.8) return 0xFF3FB950; // Green - high
    if (score >= 0.5) return 0xFFD29922; // Yellow - medium
    return 0xFFF85149; // Red - low
  }

  /// Get display label
  String get displayLabel {
    if (score >= 0.8) return 'High Confidence';
    if (score >= 0.5) return 'Medium Confidence';
    return 'Low Confidence';
  }

  /// Get percentage string
  String get percentageString => '${(score * 100).round()}%';
}

class JobCost {
  final double totalUsd;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final String model;

  JobCost({
    required this.totalUsd,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.model,
  });

  factory JobCost.fromMap(Map<String, dynamic> map) {
    return JobCost(
      totalUsd: (map['total_usd'] as num?)?.toDouble() ?? 0.0,
      inputTokens: (map['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (map['output_tokens'] as num?)?.toInt() ?? 0,
      cacheReadTokens: (map['cache_read_tokens'] as num?)?.toInt() ?? 0,
      cacheCreationTokens: (map['cache_creation_tokens'] as num?)?.toInt() ?? 0,
      model: map['model'] as String? ?? 'unknown',
    );
  }

  String get formattedCost => '\$${totalUsd.toStringAsFixed(4)}';

  int get totalTokens => inputTokens + outputTokens;

  double get cacheHitRate {
    if (inputTokens == 0) return 0;
    return cacheReadTokens / inputTokens;
  }
}

class Job {
  final String issueId;
  final String status;
  final String command;
  final int startTime;
  final int? completedTime;
  final String? error;
  final String repo;
  final String repoSlug;
  final String issueTitle;
  final int issueNum;
  final String logPath;
  final String localPath;
  final String fullCommand;
  final JobCost? cost;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<JobDecision> decisions;
  final JobConfidence? confidence;

  Job({
    required this.issueId,
    required this.status,
    required this.command,
    required this.startTime,
    this.completedTime,
    this.error,
    required this.repo,
    required this.repoSlug,
    required this.issueTitle,
    required this.issueNum,
    required this.logPath,
    required this.localPath,
    required this.fullCommand,
    this.cost,
    required this.createdAt,
    required this.updatedAt,
    this.decisions = const [],
    this.confidence,
  });

  /// Create from HTTP API response (legacy format)
  factory Job.fromJson(String issueId, Map<String, dynamic> json) {
    // Handle start_time as either int or double from JSON
    final rawStartTime = json['start_time'];
    final int startTime;
    if (rawStartTime is int) {
      startTime = rawStartTime;
    } else if (rawStartTime is double) {
      startTime = rawStartTime.toInt();
    } else {
      startTime = 0;
    }

    return Job(
      issueId: issueId,
      status: json['status'] as String? ?? 'unknown',
      command: json['command'] as String? ?? 'unknown',
      startTime: startTime,
      completedTime: json['completed_time'] as int?,
      error: json['error'] as String?,
      repo: json['repo'] as String? ?? 'unknown',
      repoSlug: json['repo_slug'] as String? ?? '',
      issueTitle: json['issue_title'] as String? ?? '',
      issueNum: json['issue_num'] as int? ?? 0,
      logPath: json['log_path'] as String? ?? '',
      localPath: json['local_path'] as String? ?? '',
      fullCommand: json['full_command'] as String? ?? '',
      cost: json['cost'] != null ? JobCost.fromMap(json['cost'] as Map<String, dynamic>) : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      decisions: _parseDecisions(json['decisions']),
      confidence: _parseConfidence(json['confidence']),
    );
  }

  static List<JobDecision> _parseDecisions(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .whereType<Map<String, dynamic>>()
        .map((e) => JobDecision.fromJson(e))
        .toList();
  }

  /// Create from Firestore document
  factory Job.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Job(
      issueId: doc.id,
      status: data['status'] as String? ?? 'unknown',
      command: data['command'] as String? ?? 'unknown',
      startTime: (data['start_time'] as num?)?.toInt() ?? 0,
      completedTime: (data['completed_time'] as num?)?.toInt(),
      error: data['error'] as String?,
      repo: data['repo'] as String? ?? 'unknown',
      repoSlug: data['repo_slug'] as String? ?? '',
      issueTitle: data['issue_title'] as String? ?? '',
      issueNum: (data['issue_num'] as num?)?.toInt() ?? 0,
      logPath: data['log_path'] as String? ?? '',
      localPath: data['local_path'] as String? ?? '',
      fullCommand: data['full_command'] as String? ?? '',
      cost: data['cost'] != null ? JobCost.fromMap(data['cost'] as Map<String, dynamic>) : null,
      createdAt: _parseFirestoreTimestamp(data['created_at']),
      updatedAt: _parseFirestoreTimestamp(data['updated_at']),
      decisions: _parseDecisions(data['decisions']),
      confidence: _parseConfidence(data['confidence']),
    );
  }

  static JobConfidence? _parseConfidence(dynamic json) {
    if (json == null) return null;
    if (json is! Map<String, dynamic>) return null;
    return JobConfidence.fromJson(json);
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime _parseFirestoreTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  JobStatus get jobStatus {
    switch (status.toLowerCase()) {
      case 'running':
        return JobStatus.running;
      case 'failed':
        return JobStatus.failed;
      case 'pending':
        return JobStatus.pending;
      case 'completed':
        return JobStatus.completed;
      case 'waiting_approval':
        return JobStatus.waitingApproval;
      case 'rejected':
        return JobStatus.rejected;
      case 'interrupted':
        return JobStatus.interrupted;
      case 'approved_resume':
        return JobStatus.approvedResume;
      case 'blocked':
        return JobStatus.blocked;
      default:
        return JobStatus.unknown;
    }
  }

  bool get needsApproval => jobStatus == JobStatus.waitingApproval;

  /// Whether the job needs user attention (blocked, failed, waiting)
  bool get needsAttention =>
      jobStatus == JobStatus.blocked ||
      jobStatus == JobStatus.failed ||
      jobStatus == JobStatus.waitingApproval;

  bool get isActive =>
    jobStatus == JobStatus.pending ||
    jobStatus == JobStatus.running ||
    jobStatus == JobStatus.waitingApproval;

  DateTime get startDateTime {
    return DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
  }

  String get formattedStartTime {
    final dt = startDateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String get shortCommand => command.replaceAll('-headless', '');

  Duration? get duration {
    if (completedTime == null) return null;
    return Duration(seconds: completedTime! - startTime);
  }

  String? get formattedDuration {
    final d = duration;
    if (d == null) return null;
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  static Map<String, Job> parseStatusResponse(dynamic json) {
    final Map<String, Job> jobs = {};

    if (json is List) {
      // Handle array response: [{"issue_id": "123", ...}, ...]
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          final issueId = (item['issue_id'] ?? item['issueId'] ?? '').toString();
          if (issueId.isNotEmpty) {
            jobs[issueId] = Job.fromJson(issueId, item);
          }
        }
      }
    } else if (json is Map<String, dynamic>) {
      // Handle object response: {"123": {...}, "456": {...}}
      json.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          jobs[key] = Job.fromJson(key, value);
        }
      });
    }

    return jobs;
  }
}
