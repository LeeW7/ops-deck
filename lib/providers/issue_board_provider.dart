import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/issue_model.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';

/// Provider for the issue-centric Kanban board
class IssueBoardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, Issue> _issues = {};
  Set<String> _selectedRepos = {};
  List<Map<String, String>> _availableRepos = [];
  String? _error;
  bool _isLoading = false;
  bool _isConfigured = false;
  Timer? _pollingTimer;

  // Getters
  Map<String, Issue> get issues => _issues;
  Set<String> get selectedRepos => _selectedRepos;
  List<Map<String, String>> get availableRepos => _availableRepos;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isConfigured => _isConfigured;

  /// Get all issues sorted by last activity time
  List<Issue> get allIssues {
    final issueList = _issues.values.toList();
    issueList.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
    return issueList;
  }

  /// Get issues filtered by selected repos
  List<Issue> get filteredIssues {
    if (_selectedRepos.isEmpty) return allIssues;
    return allIssues.where((issue) => _selectedRepos.contains(issue.repo)).toList();
  }

  /// Get issues for a specific Kanban column
  List<Issue> issuesForStatus(IssueStatus status) {
    return filteredIssues.where((issue) => issue.status == status).toList();
  }

  /// Count issues for a status
  int countForStatus(IssueStatus status) {
    return issuesForStatus(status).length;
  }

  /// Issues needing action
  List<Issue> get needsActionIssues => issuesForStatus(IssueStatus.needsAction);

  /// Running issues
  List<Issue> get runningIssues => issuesForStatus(IssueStatus.running);

  /// Failed issues
  List<Issue> get failedIssues => issuesForStatus(IssueStatus.failed);

  /// Done issues
  List<Issue> get doneIssues => issuesForStatus(IssueStatus.done);

  /// Check if any issues need attention
  bool get hasIssuesNeedingAttention =>
      needsActionIssues.isNotEmpty || failedIssues.isNotEmpty;

  /// Initialize the provider
  Future<void> initialize() async {
    final baseUrl = await _apiService.getBaseUrl();
    _isConfigured = baseUrl != null && baseUrl.isNotEmpty;

    if (_isConfigured) {
      await Future.wait([
        fetchRepos(),
        fetchJobs(),
      ]);
    }

    notifyListeners();
  }

  /// Fetch available repositories
  Future<void> fetchRepos() async {
    try {
      _availableRepos = await _apiService.fetchRepos();
      notifyListeners();
    } catch (e) {
      // Silently fail - repos are optional
    }
  }

  /// Fetch jobs and aggregate into issues
  Future<void> fetchJobs() async {
    if (!_isConfigured) {
      _error = 'Server not configured';
      notifyListeners();
      return;
    }

    try {
      _isLoading = _issues.isEmpty;
      _error = null;
      if (_isLoading) notifyListeners();

      final jobs = await _apiService.fetchStatus();
      _issues = _aggregateJobsIntoIssues(jobs);
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Aggregate jobs into issues
  Map<String, Issue> _aggregateJobsIntoIssues(Map<String, Job> jobs) {
    // Group jobs by issue key (repoSlug-issueNum)
    final Map<String, List<Job>> jobsByIssue = {};

    for (final job in jobs.values) {
      final repoSlug = job.repo.split('/').last;
      final issueKey = '$repoSlug-${job.issueNum}';

      jobsByIssue.putIfAbsent(issueKey, () => []);
      jobsByIssue[issueKey]!.add(job);
    }

    // Create Issue objects from grouped jobs
    final Map<String, Issue> issues = {};

    for (final entry in jobsByIssue.entries) {
      final jobList = entry.value;
      if (jobList.isEmpty) continue;

      final firstJob = jobList.first;

      // Determine completed phases from jobs
      final completedPhases = <String>[];
      for (final job in jobList) {
        if (job.jobStatus == JobStatus.completed) {
          if (job.command == 'plan-headless' && !completedPhases.contains('plan')) {
            completedPhases.add('plan');
          } else if (job.command == 'implement-headless' && !completedPhases.contains('implement')) {
            completedPhases.add('implement');
          } else if (job.command == 'retrospective-headless' && !completedPhases.contains('retrospective')) {
            completedPhases.add('retrospective');
          }
        }
      }

      issues[entry.key] = Issue.fromJobs(
        issueNum: firstJob.issueNum,
        repo: firstJob.repo,
        jobs: jobList,
        completedPhases: completedPhases,
      );
    }

    return issues;
  }

  /// Fetch workflow state for a specific issue (enriches issue data)
  Future<Issue?> fetchIssueWorkflowState(String repo, int issueNum) async {
    try {
      final workflow = await _apiService.fetchWorkflowState(repo, issueNum);
      final repoSlug = repo.split('/').last;
      final issueKey = '$repoSlug-$issueNum';

      if (_issues.containsKey(issueKey)) {
        final existingIssue = _issues[issueKey]!;
        final updatedIssue = existingIssue.copyWith(
          currentPhase: WorkflowPhase.fromString(workflow['current_phase'] ?? 'new'),
          prUrl: workflow['pr_url'] as String?,
          canRevise: workflow['can_revise'] as bool? ?? false,
          canMerge: workflow['can_merge'] as bool? ?? false,
          issueClosed: workflow['issue_closed'] as bool? ?? false,
          revisionCount: workflow['revision_count'] as int? ?? 0,
          completedPhases: (workflow['completed_phases'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        );
        _issues[issueKey] = updatedIssue;
        notifyListeners();
        return updatedIssue;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Toggle repo filter
  void toggleRepoFilter(String repo) {
    if (_selectedRepos.contains(repo)) {
      _selectedRepos.remove(repo);
    } else {
      _selectedRepos.add(repo);
    }
    notifyListeners();
  }

  /// Clear all repo filters
  void clearRepoFilters() {
    _selectedRepos.clear();
    notifyListeners();
  }

  /// Start polling for updates
  void startPolling() {
    stopPolling();
    fetchJobs();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      fetchJobs();
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Get a specific issue
  Issue? getIssue(String key) => _issues[key];

  /// Proceed with issue (trigger next phase)
  Future<bool> proceedWithIssue(String repo, int issueNum) async {
    try {
      await _apiService.proceedWithIssue(repo, issueNum);
      await fetchJobs(); // Refresh
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Post feedback on an issue
  Future<bool> postFeedback(String repo, int issueNum, String feedback, {String? imageUrl}) async {
    try {
      await _apiService.postFeedback(repo, issueNum, feedback, imageUrl: imageUrl);
      await fetchJobs(); // Refresh
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Merge PR for an issue
  Future<bool> mergePR(String repo, int issueNum, {String method = 'squash'}) async {
    try {
      await _apiService.mergePr(repo, issueNum, method: method);
      await fetchJobs(); // Refresh
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
