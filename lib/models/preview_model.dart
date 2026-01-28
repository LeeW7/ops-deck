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
    return PreviewDeployment(
      id: json['id'] as String? ?? '',
      issueKey: json['issue_key'] as String? ?? json['issueKey'] as String? ?? '',
      projectType: ProjectType.fromString(json['project_type'] as String? ?? json['projectType'] as String? ?? ''),
      status: PreviewStatus.fromString(json['status'] as String? ?? ''),
      previewUrl: json['preview_url'] as String? ?? json['previewUrl'] as String?,
      downloadUrl: json['download_url'] as String? ?? json['downloadUrl'] as String?,
      qrCodeUrl: json['qr_code_url'] as String? ?? json['qrCodeUrl'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as num).toInt() * 1000)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['expires_at'] as num).toInt() * 1000)
          : json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
      errorMessage: json['error_message'] as String? ?? json['errorMessage'] as String?,
      buildId: json['build_id'] as String? ?? json['buildId'] as String?,
      commitSha: json['commit_sha'] as String? ?? json['commitSha'] as String?,
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
    return TestFailure(
      testName: json['test_name'] as String? ?? json['testName'] as String? ?? 'Unknown test',
      suiteName: json['suite_name'] as String? ?? json['suiteName'] as String?,
      message: json['message'] as String? ?? '',
      stackTrace: json['stack_trace'] as String? ?? json['stackTrace'] as String?,
      filePath: json['file_path'] as String? ?? json['filePath'] as String?,
      lineNumber: json['line_number'] as int? ?? json['lineNumber'] as int?,
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
    return TestResult(
      id: json['id'] as String? ?? '',
      testSuite: json['test_suite'] as String? ?? json['testSuite'] as String? ?? 'Tests',
      passed: json['passed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      coveragePercent: json['coverage_percent'] as String? ?? json['coveragePercent'] as String? ?? json['coverage'] as String?,
      failures: (json['failures'] as List<dynamic>?)
              ?.map((f) => TestFailure.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is num
              ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt() * 1000)
              : DateTime.parse(json['timestamp'] as String))
          : DateTime.now(),
      runUrl: json['run_url'] as String? ?? json['runUrl'] as String?,
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
    return ValidationState(
      issueKey: json['issue_key'] as String? ?? json['issueKey'] as String? ?? '',
      preview: json['preview'] != null
          ? PreviewDeployment.fromJson(json['preview'] as Map<String, dynamic>)
          : null,
      testResults: (json['test_results'] as List<dynamic>? ?? json['testResults'] as List<dynamic>?)
              ?.map((t) => TestResult.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      phase: ValidationPhase.fromString(json['phase'] as String? ?? ''),
      lastUpdated: json['last_updated'] != null || json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              ((json['last_updated'] ?? json['lastUpdated']) as num).toInt() * 1000)
          : null,
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
