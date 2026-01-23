import 'job_model.dart';

/// Workflow phases for an issue
enum WorkflowPhase {
  newIssue,
  planning,
  planComplete,
  implementing,
  review,
  complete;

  static WorkflowPhase fromString(String value) {
    switch (value) {
      case 'new':
        return WorkflowPhase.newIssue;
      case 'planning':
        return WorkflowPhase.planning;
      case 'plan_complete':
        return WorkflowPhase.planComplete;
      case 'implementing':
        return WorkflowPhase.implementing;
      case 'review':
        return WorkflowPhase.review;
      case 'complete':
        return WorkflowPhase.complete;
      default:
        return WorkflowPhase.newIssue;
    }
  }

  String get displayName {
    switch (this) {
      case WorkflowPhase.newIssue:
        return 'New';
      case WorkflowPhase.planning:
        return 'Planning...';
      case WorkflowPhase.planComplete:
        return 'Plan Ready';
      case WorkflowPhase.implementing:
        return 'Implementing...';
      case WorkflowPhase.review:
        return 'In Review';
      case WorkflowPhase.complete:
        return 'Complete';
    }
  }
}

/// Issue status for Kanban board columns
enum IssueStatus {
  needsAction,
  running,
  failed,
  done;

  String get displayName {
    switch (this) {
      case IssueStatus.needsAction:
        return 'NEEDS ACTION';
      case IssueStatus.running:
        return 'RUNNING';
      case IssueStatus.failed:
        return 'FAILED';
      case IssueStatus.done:
        return 'DONE';
    }
  }

  /// Kanban column color
  int get colorValue {
    switch (this) {
      case IssueStatus.needsAction:
        return 0xFFF0883E; // Orange
      case IssueStatus.running:
        return 0xFF3FB950; // Green
      case IssueStatus.failed:
        return 0xFFF85149; // Red
      case IssueStatus.done:
        return 0xFF8B949E; // Gray
    }
  }
}

/// Aggregated issue model for the Kanban board
/// Each issue appears once, with all its jobs aggregated
class Issue {
  final int issueNum;
  final String repo;
  final String repoSlug;
  final String title;
  final List<Job> jobs;
  final WorkflowPhase currentPhase;
  final String? prUrl;
  final bool canRevise;
  final bool canMerge;
  final bool issueClosed;
  final int revisionCount;
  final List<String> completedPhases;

  Issue({
    required this.issueNum,
    required this.repo,
    required this.repoSlug,
    required this.title,
    required this.jobs,
    required this.currentPhase,
    this.prUrl,
    this.canRevise = false,
    this.canMerge = false,
    this.issueClosed = false,
    this.revisionCount = 0,
    this.completedPhases = const [],
  });

  /// Derive issue status from jobs for Kanban column placement
  IssueStatus get status {
    // Check if any job is running
    if (jobs.any((j) => j.jobStatus == JobStatus.running || j.jobStatus == JobStatus.pending)) {
      return IssueStatus.running;
    }

    // Check if any job failed
    if (jobs.any((j) => j.jobStatus == JobStatus.failed)) {
      return IssueStatus.failed;
    }

    // Check if any job is blocked (needs attention but not a hard failure)
    if (jobs.any((j) => j.jobStatus == JobStatus.blocked)) {
      return IssueStatus.needsAction;
    }

    // Check if any job needs approval
    if (jobs.any((j) => j.jobStatus == JobStatus.waitingApproval)) {
      return IssueStatus.needsAction;
    }

    // Check if workflow is complete
    if (currentPhase == WorkflowPhase.complete) {
      return IssueStatus.done;
    }

    // Default: needs action (user needs to trigger next phase)
    return IssueStatus.needsAction;
  }

  /// Get the blocked job (if any)
  Job? get blockedJob {
    return jobs.cast<Job?>().firstWhere(
      (j) => j?.jobStatus == JobStatus.blocked,
      orElse: () => null,
    );
  }

  /// Get the latest (most recent) job
  Job? get latestJob {
    if (jobs.isEmpty) return null;
    final sorted = List<Job>.from(jobs)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.first;
  }

  /// Get the currently running job (if any)
  Job? get runningJob {
    return jobs.cast<Job?>().firstWhere(
      (j) => j?.jobStatus == JobStatus.running || j?.jobStatus == JobStatus.pending,
      orElse: () => null,
    );
  }

  /// Get the failed job (if any)
  Job? get failedJob {
    return jobs.cast<Job?>().firstWhere(
      (j) => j?.jobStatus == JobStatus.failed,
      orElse: () => null,
    );
  }

  /// Unique key for this issue
  String get key => '$repoSlug-$issueNum';

  /// Time of most recent activity
  DateTime get lastActivityTime {
    if (jobs.isEmpty) return DateTime.now();
    final sorted = List<Job>.from(jobs)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.first.startDateTime;
  }

  /// Create an Issue from a list of jobs belonging to the same issue
  factory Issue.fromJobs({
    required int issueNum,
    required String repo,
    required List<Job> jobs,
    WorkflowPhase? phase,
    String? prUrl,
    bool canRevise = false,
    bool canMerge = false,
    bool issueClosed = false,
    int revisionCount = 0,
    List<String> completedPhases = const [],
  }) {
    final repoSlug = repo.split('/').last;
    final title = jobs.isNotEmpty ? jobs.first.issueTitle : 'Issue #$issueNum';

    return Issue(
      issueNum: issueNum,
      repo: repo,
      repoSlug: repoSlug,
      title: title,
      jobs: jobs,
      currentPhase: phase ?? _inferPhase(jobs, completedPhases),
      prUrl: prUrl,
      canRevise: canRevise,
      canMerge: canMerge,
      issueClosed: issueClosed,
      revisionCount: revisionCount,
      completedPhases: completedPhases,
    );
  }

  /// Infer workflow phase from jobs
  static WorkflowPhase _inferPhase(List<Job> jobs, List<String> completedPhases) {
    if (completedPhases.contains('retrospective')) {
      return WorkflowPhase.complete;
    }
    if (completedPhases.contains('implement')) {
      return WorkflowPhase.review;
    }
    if (completedPhases.contains('plan')) {
      return WorkflowPhase.planComplete;
    }

    // Check if plan is currently running
    final planJob = jobs.cast<Job?>().firstWhere(
      (j) => j?.command == 'plan-headless',
      orElse: () => null,
    );
    if (planJob != null &&
        (planJob.jobStatus == JobStatus.running || planJob.jobStatus == JobStatus.pending)) {
      return WorkflowPhase.planning;
    }

    return WorkflowPhase.newIssue;
  }

  /// Copy with updated values
  Issue copyWith({
    int? issueNum,
    String? repo,
    String? repoSlug,
    String? title,
    List<Job>? jobs,
    WorkflowPhase? currentPhase,
    String? prUrl,
    bool? canRevise,
    bool? canMerge,
    bool? issueClosed,
    int? revisionCount,
    List<String>? completedPhases,
  }) {
    return Issue(
      issueNum: issueNum ?? this.issueNum,
      repo: repo ?? this.repo,
      repoSlug: repoSlug ?? this.repoSlug,
      title: title ?? this.title,
      jobs: jobs ?? this.jobs,
      currentPhase: currentPhase ?? this.currentPhase,
      prUrl: prUrl ?? this.prUrl,
      canRevise: canRevise ?? this.canRevise,
      canMerge: canMerge ?? this.canMerge,
      issueClosed: issueClosed ?? this.issueClosed,
      revisionCount: revisionCount ?? this.revisionCount,
      completedPhases: completedPhases ?? this.completedPhases,
    );
  }
}
