import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/issue_model.dart';
import '../models/job_model.dart';
import '../models/file_diff_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/job_cache_service.dart';

/// Callback type for showing toast notifications
typedef ToastCallback = void Function(String message, {VoidCallback? onUndo});

/// Provider for the issue-centric Kanban board
/// Uses WebSocket for real-time updates, SQLite cache for instant startup
class IssueBoardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GlobalEventsService _globalEvents = GlobalEventsService();
  final JobCacheService _cache = JobCacheService();

  Map<String, Issue> _issues = {};
  Set<String> _selectedRepos = {};
  List<Map<String, String>> _availableRepos = [];
  String? _error;
  bool _isLoading = false;
  bool _isConfigured = false;
  bool _cacheLoaded = false;
  Timer? _pollingTimer;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _connectionSubscription;

  // Hidden issues support
  Set<String> _hiddenIssueKeys = {};
  Issue? _recentlyHiddenIssue;
  Timer? _undoTimer;

  // Diff tracking for pending changes
  final Map<String, JobDiffSummary> _jobDiffs = {};

  // Getters
  Map<String, Issue> get issues => _issues;
  Set<String> get selectedRepos => _selectedRepos;
  List<Map<String, String>> get availableRepos => _availableRepos;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isConfigured => _isConfigured;
  bool get isWebSocketConnected => _globalEvents.state == WsConnectionState.connected;

  /// Get all issues sorted by last activity time
  List<Issue> get allIssues {
    final issueList = _issues.values.toList();
    issueList.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
    return issueList;
  }

  /// Get issues filtered by selected repos AND excluding hidden issues
  List<Issue> get filteredIssues {
    var issues = allIssues;
    // Filter out hidden issues
    issues = issues.where((issue) => !_hiddenIssueKeys.contains(issue.key)).toList();
    // Filter by selected repos
    if (_selectedRepos.isNotEmpty) {
      issues = issues.where((issue) => _selectedRepos.contains(issue.repo)).toList();
    }
    return issues;
  }

  /// Check if there's a recent hide that can be undone
  bool get canUndoHide => _recentlyHiddenIssue != null;

  /// Get diff summary for a job
  JobDiffSummary? getDiffSummary(String jobId) => _jobDiffs[jobId];

  /// Check if a job has pending diffs
  bool hasDiffs(String jobId) => _jobDiffs.containsKey(jobId) && (_jobDiffs[jobId]?.diffs.isNotEmpty ?? false);

  /// Add a file diff for a job
  void addFileDiff(String jobId, FileDiff diff) {
    final existing = _jobDiffs[jobId] ?? JobDiffSummary.empty(jobId);
    _jobDiffs[jobId] = existing.withDiff(diff);
    notifyListeners();
  }

  /// Clear diffs for a job (when job completes or is rejected)
  void clearDiffs(String jobId) {
    _jobDiffs.remove(jobId);
    notifyListeners();
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

    // Load cached data first for instant UI
    await _loadFromCache();
    // Load hidden issues
    await _loadHiddenIssues();

    if (_isConfigured) {
      await fetchRepos();
      // Connect to WebSocket for real-time updates
      _connectWebSocket();
      // Fetch fresh data in background
      fetchJobs();
    }

    notifyListeners();
  }

  /// Load hidden issues from cache on initialization
  Future<void> _loadHiddenIssues() async {
    try {
      // First load from local cache for instant display
      _hiddenIssueKeys = await _cache.getHiddenIssueKeys();
      if (kDebugMode) {
        print('[IssueBoardProvider] Loaded ${_hiddenIssueKeys.length} hidden issues from cache');
      }

      // Then sync from server (will update cache)
      await _syncHiddenIssuesFromServer();
    } catch (e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Failed to load hidden issues: $e');
      }
    }
  }

  /// Sync hidden issues from the server and update local cache
  Future<void> _syncHiddenIssuesFromServer() async {
    try {
      final serverHidden = await _apiService.fetchHiddenIssues();
      final serverKeys = serverHidden.map((h) => h.issueKey).toSet();

      // Update local state with server data
      _hiddenIssueKeys = serverKeys;

      // Update local cache to match server
      final localKeys = await _cache.getHiddenIssueKeys();

      // Add any new ones from server to local cache
      for (final hidden in serverHidden) {
        if (!localKeys.contains(hidden.issueKey)) {
          await _cache.hideIssue(
            issueKey: hidden.issueKey,
            repo: hidden.repo,
            issueNum: hidden.issueNum,
            issueTitle: hidden.issueTitle,
            reason: hidden.reason,
          );
        }
      }

      // Remove any local ones not on server
      for (final localKey in localKeys) {
        if (!serverKeys.contains(localKey)) {
          await _cache.unhideIssue(localKey);
        }
      }

      if (kDebugMode) {
        print('[IssueBoardProvider] Synced ${serverKeys.length} hidden issues from server');
      }

      notifyListeners();
    } catch (e) {
      // Server sync failed - keep using local cache
      if (kDebugMode) {
        print('[IssueBoardProvider] Server sync failed, using local cache: $e');
      }
    }
  }

  /// Load jobs from local cache for instant startup
  Future<void> _loadFromCache() async {
    try {
      final cachedJobs = await _cache.getAllJobs();
      if (cachedJobs.isNotEmpty) {
        final jobsMap = {for (var job in cachedJobs) job.issueId: job};
        _issues = _aggregateJobsIntoIssues(jobsMap);
        _cacheLoaded = true;
        if (kDebugMode) {
          print('[IssueBoardProvider] Loaded ${cachedJobs.length} jobs from cache');
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Cache load error: $e');
      }
    }
  }

  /// Save jobs to cache
  Future<void> _saveToCache(List<Job> jobs) async {
    try {
      await _cache.saveJobs(jobs);
      await _cache.updateLastSyncTime();
      // Clean up old jobs periodically
      await _cache.deleteOldJobs(keepDays: 30);
    } catch (e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Cache save error: $e');
      }
    }
  }

  /// Connect to global WebSocket for real-time job events
  void _connectWebSocket() {
    // Listen for connection state changes
    _connectionSubscription = _globalEvents.connectionState.listen((state) {
      if (kDebugMode) {
        print('[IssueBoardProvider] WebSocket state: $state');
      }
      notifyListeners();
    });

    // Listen for job events
    _eventsSubscription = _globalEvents.events.listen(_handleJobEvent);

    // Connect
    _globalEvents.connect();
  }

  /// Handle incoming job event from WebSocket
  void _handleJobEvent(JobEvent event) {
    if (kDebugMode) {
      print('[IssueBoardProvider] Received event: ${event.type} for ${event.job.id}');
    }

    final job = event.job;
    final repoSlug = job.repo.split('/').last;
    final issueKey = '$repoSlug-${job.issueNum}';

    switch (event.type) {
      case JobEventType.jobCreated:
      case JobEventType.jobStatusChanged:
      case JobEventType.jobCompleted:
      case JobEventType.jobFailed:
        // Update or create the issue with new job status
        _updateIssueFromEvent(issueKey, job);
        // Update cache with new status
        _cache.updateJobStatus(job.id, job.status);
        notifyListeners();
        break;
      case JobEventType.unknown:
        break;
    }
  }

  /// Update issue state from a job event
  void _updateIssueFromEvent(String issueKey, JobEventData jobData) {
    // Auto-restore hidden issues when new activity appears
    if (_hiddenIssueKeys.contains(issueKey)) {
      _hiddenIssueKeys.remove(issueKey);
      _cache.unhideIssue(issueKey);

      // Sync removal to server
      _apiService.removeHiddenIssue(issueKey).catchError((e) {
        if (kDebugMode) {
          print('[IssueBoardProvider] Failed to sync auto-restore to server: $e');
        }
      });

      if (kDebugMode) {
        print('[IssueBoardProvider] Auto-restored hidden issue: $issueKey');
      }
    }

    // Get existing issue or create placeholder
    var issue = _issues[issueKey];
    final now = DateTime.now();

    if (issue == null) {
      // Create new issue from job data
      final newJob = Job(
        issueId: jobData.id,
        repo: jobData.repo,
        repoSlug: jobData.repo.split('/').last,
        issueNum: jobData.issueNum,
        issueTitle: jobData.issueTitle,
        command: jobData.command,
        status: jobData.status,
        startTime: now.millisecondsSinceEpoch ~/ 1000,
        logPath: '',
        localPath: '',
        fullCommand: '',
        createdAt: now,
        updatedAt: now,
      );

      issue = Issue.fromJobs(
        issueNum: jobData.issueNum,
        repo: jobData.repo,
        jobs: [newJob],
        completedPhases: [],
      );
      _issues[issueKey] = issue;
    } else {
      // Update existing issue's job list
      final updatedJobs = <Job>[];
      bool jobFound = false;

      for (final j in issue.jobs) {
        if (j.issueId == jobData.id) {
          // Update existing job with new status
          updatedJobs.add(Job(
            issueId: j.issueId,
            repo: j.repo,
            repoSlug: j.repoSlug,
            issueNum: j.issueNum,
            issueTitle: j.issueTitle,
            command: j.command,
            status: jobData.status,
            startTime: j.startTime,
            completedTime: j.completedTime,
            error: j.error,
            logPath: j.logPath,
            localPath: j.localPath,
            fullCommand: j.fullCommand,
            cost: j.cost,
            createdAt: j.createdAt,
            updatedAt: now,
          ));
          jobFound = true;
        } else {
          updatedJobs.add(j);
        }
      }

      // Add new job if not found
      if (!jobFound) {
        updatedJobs.add(Job(
          issueId: jobData.id,
          repo: jobData.repo,
          repoSlug: jobData.repo.split('/').last,
          issueNum: jobData.issueNum,
          issueTitle: jobData.issueTitle,
          command: jobData.command,
          status: jobData.status,
          startTime: now.millisecondsSinceEpoch ~/ 1000,
          logPath: '',
          localPath: '',
          fullCommand: '',
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Recalculate completed phases
      final completedPhases = <String>[];
      for (final j in updatedJobs) {
        if (j.jobStatus == JobStatus.completed) {
          if (j.command == 'plan-headless' && !completedPhases.contains('plan')) {
            completedPhases.add('plan');
          } else if (j.command == 'implement-headless' && !completedPhases.contains('implement')) {
            completedPhases.add('implement');
          } else if (j.command == 'retrospective-headless' && !completedPhases.contains('retrospective')) {
            completedPhases.add('retrospective');
          }
        }
      }

      _issues[issueKey] = Issue.fromJobs(
        issueNum: issue.issueNum,
        repo: issue.repo,
        jobs: updatedJobs,
        completedPhases: completedPhases,
      );
    }
  }

  /// Fetch available repositories
  Future<void> fetchRepos() async {
    try {
      final newRepos = await _apiService.fetchRepos();
      // Only notify if repos changed
      if (_availableRepos.length != newRepos.length) {
        _availableRepos = newRepos;
        notifyListeners();
      }
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
      final wasEmpty = _issues.isEmpty && !_cacheLoaded;
      if (wasEmpty && !_isLoading) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      final jobs = await _apiService.fetchStatus();
      final newIssues = _aggregateJobsIntoIssues(jobs);

      // Save to cache in background
      _saveToCache(jobs.values.toList());

      // Check what changed
      final wasLoading = _isLoading;
      final dataChanged = _hasIssuesChanged(newIssues);

      _isLoading = false;

      // Notify if loading state changed OR data changed
      if (wasLoading || dataChanged) {
        _issues = newIssues;
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Check if issues have changed
  bool _hasIssuesChanged(Map<String, Issue> newIssues) {
    if (_issues.length != newIssues.length) return true;
    for (final entry in newIssues.entries) {
      final oldIssue = _issues[entry.key];
      if (oldIssue == null) return true;
      if (oldIssue.status != entry.value.status) return true;
      if (oldIssue.currentPhase != entry.value.currentPhase) return true;
      if (oldIssue.jobs.length != entry.value.jobs.length) return true;
      // Check if any job has new decisions
      for (int i = 0; i < oldIssue.jobs.length && i < entry.value.jobs.length; i++) {
        if (oldIssue.jobs[i].decisions.length != entry.value.jobs[i].decisions.length) {
          return true;
        }
      }
    }
    return false;
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

  /// Start real-time updates (WebSocket + infrequent HTTP sync)
  void startRealTimeUpdates() {
    // Ensure WebSocket is connected
    if (_globalEvents.state != WsConnectionState.connected) {
      _connectWebSocket();
    }

    // Do initial fetch
    fetchJobs();

    // Start very infrequent polling as backup (60 seconds)
    // This catches any missed WebSocket events
    startPolling();
  }

  /// Stop all real-time updates
  void stopRealTimeUpdates() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _globalEvents.disconnect();
    stopPolling();
  }

  /// Start polling for updates (infrequent backup only)
  void startPolling() {
    stopPolling();
    // Very infrequent polling - just a backup for missed WebSocket events
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
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

  /// Get a specific job by ID
  Job? getJob(String jobId) {
    for (final issue in _issues.values) {
      for (final job in issue.jobs) {
        if (job.issueId == jobId) {
          return job;
        }
      }
    }
    return null;
  }

  /// Get decisions for a specific job
  List<JobDecision> getJobDecisions(String jobId) {
    final job = getJob(jobId);
    return job?.decisions ?? [];
  }

  /// Proceed with issue (trigger next phase) - legacy method
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

  /// Trigger a specific job directly
  Future<bool> triggerJob({
    required String repo,
    required int issueNum,
    required String issueTitle,
    required String command,
    String? cmdLabel,
  }) async {
    try {
      await _apiService.triggerJob(
        repo: repo,
        issueNum: issueNum,
        issueTitle: issueTitle,
        command: command,
        cmdLabel: cmdLabel,
      );
      // No need to fetchJobs - WebSocket will push the update
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

  // ============================================================================
  // Hidden Issues Methods
  // ============================================================================

  /// Hide an issue from the board (synced to server)
  Future<void> hideIssue(Issue issue) async {
    _recentlyHiddenIssue = issue;
    _hiddenIssueKeys.add(issue.key);

    // Update local cache
    await _cache.hideIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'user',
    );

    // Sync to server (fire and forget - don't block UI)
    _apiService.addHiddenIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'user',
    ).catchError((e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Failed to sync hidden issue to server: $e');
      }
    });

    notifyListeners();

    // Start undo timer (3 seconds)
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 3), () {
      _recentlyHiddenIssue = null;
      notifyListeners(); // Update UI when undo window expires
    });
  }

  /// Undo hiding the most recently hidden issue
  Future<bool> undoHideIssue() async {
    if (_recentlyHiddenIssue == null) return false;

    final issue = _recentlyHiddenIssue!;
    _hiddenIssueKeys.remove(issue.key);
    await _cache.unhideIssue(issue.key);

    // Sync removal to server (fire and forget)
    _apiService.removeHiddenIssue(issue.key).catchError((e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Failed to sync unhide to server: $e');
      }
    });

    _recentlyHiddenIssue = null;
    _undoTimer?.cancel();

    notifyListeners();
    return true;
  }

  /// Close an issue on GitHub and hide from board
  Future<void> closeIssue(Issue issue) async {
    await _apiService.closeIssue(issue.repo, issue.issueNum);

    // Hide locally after successful close
    _hiddenIssueKeys.add(issue.key);
    await _cache.hideIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'closed',
    );

    // Sync to server (fire and forget)
    _apiService.addHiddenIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'closed',
    ).catchError((e) {
      if (kDebugMode) {
        print('[IssueBoardProvider] Failed to sync closed issue to server: $e');
      }
    });

    notifyListeners();
  }

  @override
  void dispose() {
    stopRealTimeUpdates();
    _undoTimer?.cancel();
    _globalEvents.dispose();
    _cache.close();
    super.dispose();
  }
}
