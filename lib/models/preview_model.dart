/// Preview deployment status
enum PreviewStatus {
  pending,
  deploying,
  ready,
  failed,
  expired;

  static PreviewStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return PreviewStatus.pending;
      case 'deploying':
        return PreviewStatus.deploying;
      case 'ready':
        return PreviewStatus.ready;
      case 'failed':
        return PreviewStatus.failed;
      case 'expired':
        return PreviewStatus.expired;
      default:
        return PreviewStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PreviewStatus.pending:
        return 'Pending';
      case PreviewStatus.deploying:
        return 'Deploying';
      case PreviewStatus.ready:
        return 'Ready';
      case PreviewStatus.failed:
        return 'Failed';
      case PreviewStatus.expired:
        return 'Expired';
    }
  }

  /// Color value for status indicators
  int get colorValue {
    switch (this) {
      case PreviewStatus.pending:
        return 0xFF8B949E; // Gray
      case PreviewStatus.deploying:
        return 0xFFD29922; // Yellow
      case PreviewStatus.ready:
        return 0xFF238636; // Green
      case PreviewStatus.failed:
        return 0xFFF85149; // Red
      case PreviewStatus.expired:
        return 0xFF6E7681; // Dark gray
    }
  }
}

/// Project type for routing to appropriate preview strategy
enum ProjectType {
  flutter,
  web,
  backend,
  library,
  unknown;

  static ProjectType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'flutter':
        return ProjectType.flutter;
      case 'web':
        return ProjectType.web;
      case 'backend':
        return ProjectType.backend;
      case 'library':
        return ProjectType.library;
      default:
        return ProjectType.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case ProjectType.flutter:
        return 'Flutter App';
      case ProjectType.web:
        return 'Web App';
      case ProjectType.backend:
        return 'Backend';
      case ProjectType.library:
        return 'Library';
      case ProjectType.unknown:
        return 'Unknown';
    }
  }

  /// Preview platform hint
  String get previewPlatform {
    switch (this) {
      case ProjectType.flutter:
        return 'Firebase App Distribution';
      case ProjectType.web:
        return 'Vercel';
      case ProjectType.backend:
        return 'Docker';
      case ProjectType.library:
        return 'N/A';
      case ProjectType.unknown:
        return 'N/A';
    }
  }
}

/// Validation phase for tracking overall progress
enum ValidationPhase {
  pending,
  testing,
  deploying,
  ready,
  failed;

  static ValidationPhase fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return ValidationPhase.pending;
      case 'testing':
        return ValidationPhase.testing;
      case 'deploying':
        return ValidationPhase.deploying;
      case 'ready':
        return ValidationPhase.ready;
      case 'failed':
        return ValidationPhase.failed;
      default:
        return ValidationPhase.pending;
    }
  }
}

/// Preview deployment information
class PreviewDeployment {
  final String id;
  final String issueKey;
  final ProjectType projectType;
  final PreviewStatus status;
  final String? previewUrl;
  final String? downloadUrl;
  final String? qrCodeUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String? buildId;
  final String? commitSha;

  PreviewDeployment({
    required this.id,
    required this.issueKey,
    required this.projectType,
    required this.status,
    this.previewUrl,
    this.downloadUrl,
    this.qrCodeUrl,
    required this.createdAt,
    this.expiresAt,
    this.errorMessage,
    this.buildId,
    this.commitSha,
  });

  factory PreviewDeployment.fromJson(Map<String, dynamic> json) {
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

    // Parse createdAt
    DateTime createdAt;
    final createdAtNum = safeNum(json['created_at']);
    final createdAtStr = safeString(json['createdAt']);
    if (createdAtNum != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtNum.toInt() * 1000);
    } else if (createdAtStr != null) {
      createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // Parse expiresAt
    DateTime? expiresAt;
    final expiresAtNum = safeNum(json['expires_at']);
    final expiresAtStr = safeString(json['expiresAt']);
    if (expiresAtNum != null) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtNum.toInt() * 1000);
    } else if (expiresAtStr != null) {
      expiresAt = DateTime.tryParse(expiresAtStr);
    }

    return PreviewDeployment(
      id: safeString(json['id']) ?? '',
      issueKey: safeString(json['issue_key']) ?? safeString(json['issueKey']) ?? '',
      projectType: ProjectType.fromString(safeString(json['project_type']) ?? safeString(json['projectType']) ?? ''),
      status: PreviewStatus.fromString(safeString(json['status']) ?? ''),
      previewUrl: safeString(json['preview_url']) ?? safeString(json['previewUrl']),
      downloadUrl: safeString(json['download_url']) ?? safeString(json['downloadUrl']),
      qrCodeUrl: safeString(json['qr_code_url']) ?? safeString(json['qrCodeUrl']),
      createdAt: createdAt,
      expiresAt: expiresAt,
      errorMessage: safeString(json['error_message']) ?? safeString(json['errorMessage']),
      buildId: safeString(json['build_id']) ?? safeString(json['buildId']),
      commitSha: safeString(json['commit_sha']) ?? safeString(json['commitSha']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_key': issueKey,
      'project_type': projectType.name,
      'status': status.name,
      'preview_url': previewUrl,
      'download_url': downloadUrl,
      'qr_code_url': qrCodeUrl,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      if (expiresAt != null) 'expires_at': expiresAt!.millisecondsSinceEpoch ~/ 1000,
      if (errorMessage != null) 'error_message': errorMessage,
      if (buildId != null) 'build_id': buildId,
      if (commitSha != null) 'commit_sha': commitSha,
    };
  }

  /// Check if preview is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Time remaining until expiration
  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Human-readable expiration text
  String? get expirationText {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    if (remaining == Duration.zero) return 'Expired';

    if (remaining.inHours >= 24) {
      final days = remaining.inDays;
      return 'Expires in $days day${days == 1 ? '' : 's'}';
    } else if (remaining.inHours >= 1) {
      return 'Expires in ${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'}';
    } else {
      return 'Expires in ${remaining.inMinutes} minute${remaining.inMinutes == 1 ? '' : 's'}';
    }
  }

  PreviewDeployment copyWith({
    String? id,
    String? issueKey,
    ProjectType? projectType,
    PreviewStatus? status,
    String? previewUrl,
    String? downloadUrl,
    String? qrCodeUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? errorMessage,
    String? buildId,
    String? commitSha,
  }) {
    return PreviewDeployment(
      id: id ?? this.id,
      issueKey: issueKey ?? this.issueKey,
      projectType: projectType ?? this.projectType,
      status: status ?? this.status,
      previewUrl: previewUrl ?? this.previewUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      errorMessage: errorMessage ?? this.errorMessage,
      buildId: buildId ?? this.buildId,
      commitSha: commitSha ?? this.commitSha,
    );
  }
}

/// Individual test failure information
class TestFailure {
  final String testName;
  final String? suiteName;
  final String message;
  final String? stackTrace;
  final String? filePath;
  final int? lineNumber;

  TestFailure({
    required this.testName,
    this.suiteName,
    required this.message,
    this.stackTrace,
    this.filePath,
    this.lineNumber,
  });

  factory TestFailure.fromJson(Map<String, dynamic> json) {
    // Helper to safely cast to String with type check
    String? safeString(dynamic value) {
      if (value is String) return value;
      return null;
    }

    // Helper to safely cast to int with type check
    int? safeInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return null;
    }

    return TestFailure(
      testName: safeString(json['test_name']) ?? safeString(json['testName']) ?? 'Unknown test',
      suiteName: safeString(json['suite_name']) ?? safeString(json['suiteName']),
      message: safeString(json['message']) ?? '',
      stackTrace: safeString(json['stack_trace']) ?? safeString(json['stackTrace']),
      filePath: safeString(json['file_path']) ?? safeString(json['filePath']),
      lineNumber: safeInt(json['line_number']) ?? safeInt(json['lineNumber']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      if (suiteName != null) 'suite_name': suiteName,
      'message': message,
      if (stackTrace != null) 'stack_trace': stackTrace,
      if (filePath != null) 'file_path': filePath,
      if (lineNumber != null) 'line_number': lineNumber,
    };
  }

  /// Short location string (e.g., "user_test.dart:42")
  String? get location {
    if (filePath == null) return null;
    final fileName = filePath!.split('/').last;
    if (lineNumber != null) {
      return '$fileName:$lineNumber';
    }
    return fileName;
  }
}

/// Test result summary
class TestResult {
  final String id;
  final String testSuite;
  final int passed;
  final int failed;
  final int skipped;
  final double duration;
  final String? coveragePercent;
  final List<TestFailure> failures;
  final DateTime timestamp;
  final String? runUrl;

  TestResult({
    required this.id,
    required this.testSuite,
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.duration,
    this.coveragePercent,
    required this.failures,
    required this.timestamp,
    this.runUrl,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    // Helper to safely cast to String with type check
    String? safeString(dynamic value) {
      if (value is String) return value;
      return null;
    }

    // Helper to safely cast to int with type check
    int? safeInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return null;
    }

    // Helper to safely cast to num with type check
    num? safeNum(dynamic value) {
      if (value is num) return value;
      return null;
    }

    // Parse failures safely
    List<TestFailure> failures = [];
    final failuresData = json['failures'];
    if (failuresData is List) {
      failures = failuresData
          .whereType<Map<String, dynamic>>()
          .map((f) => TestFailure.fromJson(f))
          .toList();
    }

    // Parse timestamp
    DateTime timestamp;
    final ts = json['timestamp'];
    if (ts is num) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000);
    } else if (ts is String) {
      timestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }

    return TestResult(
      id: safeString(json['id']) ?? '',
      testSuite: safeString(json['test_suite']) ?? safeString(json['testSuite']) ?? 'Tests',
      passed: safeInt(json['passed']) ?? 0,
      failed: safeInt(json['failed']) ?? 0,
      skipped: safeInt(json['skipped']) ?? 0,
      duration: safeNum(json['duration'])?.toDouble() ?? 0.0,
      coveragePercent: safeString(json['coverage_percent']) ?? safeString(json['coveragePercent']) ?? safeString(json['coverage']),
      failures: failures,
      timestamp: timestamp,
      runUrl: safeString(json['run_url']) ?? safeString(json['runUrl']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_suite': testSuite,
      'passed': passed,
      'failed': failed,
      'skipped': skipped,
      'duration': duration,
      if (coveragePercent != null) 'coverage_percent': coveragePercent,
      'failures': failures.map((f) => f.toJson()).toList(),
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      if (runUrl != null) 'run_url': runUrl,
    };
  }

  /// Total number of tests
  int get total => passed + failed + skipped;

  /// Whether all tests passed (no failures)
  bool get allPassed => failed == 0 && passed > 0;

  /// Pass rate as a percentage (0-100)
  double get passRate {
    if (total == 0) return 0;
    return (passed / total) * 100;
  }

  /// Human-readable duration
  String get durationText {
    if (duration < 1) {
      return '${(duration * 1000).toInt()}ms';
    } else if (duration < 60) {
      return '${duration.toStringAsFixed(1)}s';
    } else {
      final mins = duration ~/ 60;
      final secs = (duration % 60).toInt();
      return '${mins}m ${secs}s';
    }
  }
}

/// Overall validation state for an issue
class ValidationState {
  final String issueKey;
  final PreviewDeployment? preview;
  final List<TestResult> testResults;
  final ValidationPhase phase;
  final DateTime? lastUpdated;

  ValidationState({
    required this.issueKey,
    this.preview,
    required this.testResults,
    required this.phase,
    this.lastUpdated,
  });

  factory ValidationState.fromJson(Map<String, dynamic> json) {
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

    // Parse test results safely
    List<TestResult> testResults = [];
    final testResultsData = json['test_results'] ?? json['testResults'];
    if (testResultsData is List) {
      testResults = testResultsData
          .whereType<Map<String, dynamic>>()
          .map((t) => TestResult.fromJson(t))
          .toList();
    }

    // Parse lastUpdated
    DateTime? lastUpdated;
    final lastUpdatedNum = safeNum(json['last_updated']) ?? safeNum(json['lastUpdated']);
    if (lastUpdatedNum != null) {
      lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdatedNum.toInt() * 1000);
    }

    return ValidationState(
      issueKey: safeString(json['issue_key']) ?? safeString(json['issueKey']) ?? '',
      preview: json['preview'] is Map<String, dynamic>
          ? PreviewDeployment.fromJson(json['preview'] as Map<String, dynamic>)
          : null,
      testResults: testResults,
      phase: ValidationPhase.fromString(safeString(json['phase']) ?? ''),
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_key': issueKey,
      if (preview != null) 'preview': preview!.toJson(),
      'test_results': testResults.map((t) => t.toJson()).toList(),
      'phase': phase.name,
      if (lastUpdated != null) 'last_updated': lastUpdated!.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Factory for empty/initial state
  factory ValidationState.empty(String issueKey) {
    return ValidationState(
      issueKey: issueKey,
      testResults: [],
      phase: ValidationPhase.pending,
    );
  }

  /// Whether all tests are passing
  bool get allTestsPassing {
    if (testResults.isEmpty) return false;
    return testResults.every((r) => r.allPassed);
  }

  /// Total tests passed across all suites
  int get totalPassed => testResults.fold(0, (sum, r) => sum + r.passed);

  /// Total tests failed across all suites
  int get totalFailed => testResults.fold(0, (sum, r) => sum + r.failed);

  /// Total tests skipped across all suites
  int get totalSkipped => testResults.fold(0, (sum, r) => sum + r.skipped);

  /// Total number of tests
  int get totalTests => totalPassed + totalFailed + totalSkipped;

  /// Whether preview is ready
  bool get previewReady => preview?.status == PreviewStatus.ready;

  /// Whether preview has a URL to display
  bool get hasPreviewUrl => preview?.previewUrl != null || preview?.downloadUrl != null;

  /// All test failures across all suites
  List<TestFailure> get allFailures {
    return testResults.expand((r) => r.failures).toList();
  }

  /// Best coverage from any test result
  String? get bestCoverage {
    for (final result in testResults) {
      if (result.coveragePercent != null) {
        return result.coveragePercent;
      }
    }
    return null;
  }

  ValidationState copyWith({
    String? issueKey,
    PreviewDeployment? preview,
    List<TestResult>? testResults,
    ValidationPhase? phase,
    DateTime? lastUpdated,
  }) {
    return ValidationState(
      issueKey: issueKey ?? this.issueKey,
      preview: preview ?? this.preview,
      testResults: testResults ?? this.testResults,
      phase: phase ?? this.phase,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
