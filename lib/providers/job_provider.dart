import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/job_model.dart';
import '../models/screenshot_attachment.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';

/// Tracks error state with context
class ProviderError {
  final String message;
  final ApiErrorType? type;
  final bool isRetryable;
  final DateTime timestamp;

  ProviderError({
    required this.message,
    this.type,
    this.isRetryable = false,
  }) : timestamp = DateTime.now();

  factory ProviderError.fromException(Object e) {
    if (e is ApiException) {
      return ProviderError(
        message: e.userMessage,
        type: e.type,
        isRetryable: e.isRetryable,
      );
    }
    return ProviderError(message: e.toString());
  }

  /// Whether this error is stale (older than 30 seconds)
  bool get isStale => DateTime.now().difference(timestamp).inSeconds > 30;
}

class JobProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreJobService _firestoreService = FirestoreJobService();

  Map<String, Job> _jobs = {};
  ProviderError? _error;
  bool _isLoading = false;
  bool _isConfigured = false;
  bool _useFirestore = false;
  Timer? _pollingTimer;
  StreamSubscription? _firestoreSubscription;
  DateTime? _lastSuccessfulFetch;

  Map<String, Job> get jobs => _jobs;
  ProviderError? get errorState => _error;
  String? get error => _error?.message;
  bool get isLoading => _isLoading;
  bool get isConfigured => _isConfigured;
  bool get useFirestore => _useFirestore;

  /// Whether the data may be stale (last fetch was more than 1 minute ago)
  bool get isDataStale {
    if (_lastSuccessfulFetch == null) return true;
    return DateTime.now().difference(_lastSuccessfulFetch!).inMinutes > 1;
  }

  /// Whether the current error is retryable
  bool get canRetry => _error?.isRetryable ?? false;

  List<Job> get sortedJobs {
    final jobList = _jobs.values.toList();
    // Sort by start time descending (most recent first)
    jobList.sort((a, b) => b.startTime.compareTo(a.startTime));
    return jobList;
  }

  List<Job> get runningJobs =>
      sortedJobs.where((j) => j.jobStatus == JobStatus.running).toList();

  List<Job> get failedJobs =>
      sortedJobs.where((j) => j.jobStatus == JobStatus.failed).toList();

  List<Job> get waitingApprovalJobs =>
      sortedJobs.where((j) => j.jobStatus == JobStatus.waitingApproval).toList();

  List<Job> get activeJobs =>
      sortedJobs.where((j) => j.isActive).toList();

  bool get hasJobsNeedingApproval => waitingApprovalJobs.isNotEmpty;

  /// Total cost across all jobs
  double get totalCost {
    return _jobs.values
        .where((j) => j.cost != null)
        .fold(0.0, (sum, j) => sum + j.cost!.totalUsd);
  }

  Future<void> initialize() async {
    final baseUrl = await _apiService.getBaseUrl();
    _isConfigured = baseUrl != null && baseUrl.isNotEmpty;

    // Try to enable Firestore if Firebase is initialized
    await _checkFirestoreAvailability();

    notifyListeners();
  }

  Future<void> _checkFirestoreAvailability() async {
    // Jobs are now stored in SQLite on the server, not Firestore
    // Always use HTTP polling to get jobs from the server API
    _useFirestore = false;
    if (kDebugMode) {
      print('[JobProvider] Using HTTP polling (jobs stored in SQLite)');
    }
  }

  Future<void> checkConfiguration() async {
    final baseUrl = await _apiService.getBaseUrl();
    _isConfigured = baseUrl != null && baseUrl.isNotEmpty;
    notifyListeners();
  }

  /// Fetch jobs using HTTP API (fallback)
  Future<void> fetchJobs() async {
    if (kDebugMode) {
      print('[JobProvider] fetchJobs called');
    }
    if (!_isConfigured) {
      _error = ProviderError(
        message: 'Server not configured. Go to Settings.',
        type: ApiErrorType.notConfigured,
      );
      notifyListeners();
      return;
    }

    try {
      final wasLoading = _isLoading;
      _isLoading = _jobs.isEmpty;
      // Clear stale errors on new fetch attempt
      if (_error?.isStale == true) _error = null;
      if (_isLoading && !wasLoading) notifyListeners();

      final newJobs = await _apiService.fetchStatus();
      _isLoading = false;
      _lastSuccessfulFetch = DateTime.now();

      // Only notify if data actually changed
      if (_hasJobsChanged(newJobs)) {
        _jobs = newJobs;
        _error = null;
        notifyListeners();
      } else if (_error != null) {
        // Clear error on successful fetch even if data didn't change
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = ProviderError.fromException(e);
      if (kDebugMode) {
        print('[JobProvider] Fetch error: ${_error?.message}');
      }
      notifyListeners();
    }
  }

  /// Clear the current error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Check if jobs have changed (compare keys and status)
  bool _hasJobsChanged(Map<String, Job> newJobs) {
    if (_jobs.length != newJobs.length) {
      debugPrint('[JobProvider] Jobs changed: count ${_jobs.length} -> ${newJobs.length}');
      return true;
    }
    for (final entry in newJobs.entries) {
      final oldJob = _jobs[entry.key];
      if (oldJob == null) {
        debugPrint('[JobProvider] Jobs changed: new job ${entry.key}');
        return true;
      }
      if (oldJob.status != entry.value.status) {
        debugPrint('[JobProvider] Jobs changed: ${entry.key} status ${oldJob.status} -> ${entry.value.status}');
        return true;
      }
      if (oldJob.error != entry.value.error) {
        debugPrint('[JobProvider] Jobs changed: ${entry.key} error changed');
        return true;
      }
    }
    debugPrint('[JobProvider] No changes detected');
    return false;
  }

  /// Start real-time updates (Firestore preferred, falls back to HTTP polling)
  void startRealTimeUpdates() {
    if (_useFirestore) {
      _startFirestoreListener();
    } else {
      startPolling();
    }
  }

  /// Stop all updates
  void stopRealTimeUpdates() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    stopPolling();
  }

  void _startFirestoreListener() {
    _firestoreSubscription?.cancel();
    _isLoading = _jobs.isEmpty;
    _error = null;
    if (_isLoading) notifyListeners();

    _firestoreSubscription = _firestoreService.watchJobs().listen(
      (jobs) {
        _jobs = {for (var job in jobs) job.issueId: job};
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) {
          print('[JobProvider] Firestore error, falling back to HTTP: $e');
        }
        _useFirestore = false;
        startPolling();
      },
    );
  }

  void startPolling() {
    stopPolling();
    fetchJobs();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchJobs();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Job? getJob(String issueId) => _jobs[issueId];

  /// Approve a job (always uses HTTP API to communicate with server)
  Future<bool> approveJob(String jobId) async {
    try {
      final result = await _apiService.approveJob(jobId);
      if (result && !_useFirestore) {
        await fetchJobs(); // Refresh job list if not using Firestore
      }
      return result;
    } catch (e) {
      _error = ProviderError.fromException(e);
      notifyListeners();
      return false;
    }
  }

  /// Reject a job (always uses HTTP API to communicate with server)
  Future<bool> rejectJob(String jobId) async {
    try {
      final result = await _apiService.rejectJob(jobId);
      if (result && !_useFirestore) {
        await fetchJobs(); // Refresh job list if not using Firestore
      }
      return result;
    } catch (e) {
      _error = ProviderError.fromException(e);
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    stopRealTimeUpdates();
    super.dispose();
  }
}

class LogProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String _logs = '';
  ProviderError? _error;
  bool _isLoading = false;
  Timer? _pollingTimer;
  String? _currentIssueId;
  int _consecutiveErrors = 0;

  String get logs => _logs;
  ProviderError? get errorState => _error;
  String? get error => _error?.message;
  bool get isLoading => _isLoading;
  bool get canRetry => _error?.isRetryable ?? false;

  Future<void> fetchLogs(String issueId) async {
    try {
      _isLoading = _logs.isEmpty;
      // Clear stale errors
      if (_error?.isStale == true) _error = null;
      if (_isLoading) notifyListeners();

      _logs = await _apiService.fetchLogs(issueId);
      _isLoading = false;
      _error = null;
      _consecutiveErrors = 0;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _consecutiveErrors++;
      _error = ProviderError.fromException(e);

      // Stop polling if too many consecutive errors
      if (_consecutiveErrors >= 3 && _pollingTimer != null) {
        if (kDebugMode) {
          print('[LogProvider] Stopping polling after $_consecutiveErrors consecutive errors');
        }
        stopPolling();
      }
      notifyListeners();
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      _consecutiveErrors = 0;
      notifyListeners();
    }
  }

  void startPolling(String issueId) {
    stopPolling();
    _currentIssueId = issueId;
    _logs = '';
    _error = null;
    fetchLogs(issueId);
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_currentIssueId != null) {
        fetchLogs(_currentIssueId!);
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentIssueId = null;
  }

  void clear() {
    stopPolling();
    _logs = '';
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String _baseUrl = '';
  bool _isTesting = false;
  bool? _connectionSuccess;
  String? _testError;

  String get baseUrl => _baseUrl;
  bool get isTesting => _isTesting;
  bool? get connectionSuccess => _connectionSuccess;
  String? get testError => _testError;

  Future<void> loadSettings() async {
    _baseUrl = await _apiService.getBaseUrl() ?? '';
    notifyListeners();
  }

  Future<void> saveBaseUrl(String url) async {
    await _apiService.setBaseUrl(url);
    _baseUrl = url;
    notifyListeners();
  }

  Future<bool> testConnection(String url) async {
    _isTesting = true;
    _connectionSuccess = null;
    _testError = null;
    notifyListeners();

    try {
      final success = await _apiService.testConnection(url);
      _connectionSuccess = success;
      _testError = success ? null : 'Could not connect to server';
    } catch (e) {
      _connectionSuccess = false;
      _testError = e.toString();
    }

    _isTesting = false;
    notifyListeners();
    return _connectionSuccess ?? false;
  }

  void clearTestResult() {
    _connectionSuccess = null;
    _testError = null;
    notifyListeners();
  }
}

class IssueProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  static const int maxScreenshots = 5;

  List<Map<String, String>> _repos = [];
  String? _selectedRepo;
  String _title = '';
  String _body = '';
  bool _isLoading = false;
  bool _isEnhancing = false;
  bool _isCreating = false;
  ProviderError? _error;
  String? _successMessage;
  List<ScreenshotAttachment> _screenshots = [];
  int _screenshotIdCounter = 0;
  bool _titleBodyModifiedByAI = false;

  List<Map<String, String>> get repos => _repos;
  String? get selectedRepo => _selectedRepo;
  String get title => _title;
  String get body => _body;
  bool get isLoading => _isLoading;
  bool get isEnhancing => _isEnhancing;
  bool get isCreating => _isCreating;
  ProviderError? get errorState => _error;
  String? get error => _error?.message;
  String? get successMessage => _successMessage;
  bool get canRetry => _error?.isRetryable ?? false;

  // Screenshot getters
  List<ScreenshotAttachment> get screenshots => List.unmodifiable(_screenshots);
  bool get hasScreenshots => _screenshots.isNotEmpty;
  bool get allScreenshotsUploaded =>
      _screenshots.every((s) => s.isUploaded);
  bool get hasFailedUploads =>
      _screenshots.any((s) => s.status == UploadStatus.failed);
  bool get hasPendingUploads =>
      _screenshots.any((s) => s.status == UploadStatus.uploading || s.status == UploadStatus.pending);
  int get uploadingCount =>
      _screenshots.where((s) => s.status == UploadStatus.uploading).length;
  bool get canAddMoreScreenshots => _screenshots.length < maxScreenshots;
  bool get titleBodyModifiedByAI => _titleBodyModifiedByAI;

  Future<void> fetchRepos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _repos = await _apiService.fetchRepos();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = ProviderError.fromException(e);
      notifyListeners();
    }
  }

  void setSelectedRepo(String? repo) {
    _selectedRepo = repo;
    notifyListeners();
  }

  void setTitle(String title) {
    _title = title;
    _successMessage = null;
    // Don't call notifyListeners() - avoids rebuilds while typing
  }

  void setBody(String body) {
    _body = body;
    _successMessage = null;
    // Don't call notifyListeners() - avoids rebuilds while typing
  }

  Future<void> enhanceWithAI() async {
    if (_title.isEmpty && _body.isEmpty) {
      _error = ProviderError(message: 'Please enter a title or description first');
      notifyListeners();
      return;
    }

    _isEnhancing = true;
    _error = null;
    notifyListeners();

    try {
      final enhanced = await _apiService.enhanceIssue(_title, _body, _selectedRepo);
      _title = enhanced['title'] ?? _title;
      _body = enhanced['body'] ?? '';
      _titleBodyModifiedByAI = true;
      _isEnhancing = false;
      notifyListeners();
    } catch (e) {
      _isEnhancing = false;
      _error = ProviderError.fromException(e);
      notifyListeners();
    }
  }

  Future<bool> createIssue() async {
    if (_selectedRepo == null || _selectedRepo!.isEmpty) {
      _error = ProviderError(message: 'Please select a repository');
      notifyListeners();
      return false;
    }
    if (_title.isEmpty) {
      _error = ProviderError(message: 'Please enter a title');
      notifyListeners();
      return false;
    }
    if (hasPendingUploads) {
      _error = ProviderError(message: 'Please wait for screenshots to finish uploading');
      notifyListeners();
      return false;
    }

    _isCreating = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Build body with screenshots appended as markdown
      final bodyWithScreenshots = _buildBodyWithScreenshots();
      final issueUrl = await _apiService.createIssue(_selectedRepo!, _title, bodyWithScreenshots);
      _isCreating = false;
      _successMessage = 'Issue created! $issueUrl';
      // Clear form
      _title = '';
      _body = '';
      _screenshots = [];
      notifyListeners();
      return true;
    } catch (e) {
      _isCreating = false;
      _error = ProviderError.fromException(e);
      notifyListeners();
      return false;
    }
  }

  /// Build issue body with screenshots appended as markdown images
  String _buildBodyWithScreenshots() {
    // Filter only successfully uploaded screenshots
    final uploadedScreenshots = _screenshots.where((s) => s.isUploaded).toList();
    if (uploadedScreenshots.isEmpty) {
      return _body;
    }

    final buffer = StringBuffer(_body);
    if (_body.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln('---');
    }
    buffer.writeln('### Screenshots');
    buffer.writeln();
    for (int i = 0; i < uploadedScreenshots.length; i++) {
      buffer.writeln('![Screenshot ${i + 1}](${uploadedScreenshots[i].uploadedUrl})');
    }
    return buffer.toString();
  }

  /// Add a screenshot from a local file path and start uploading
  Future<void> addScreenshot(String localPath) async {
    if (!canAddMoreScreenshots) {
      _error = ProviderError(message: 'Maximum $maxScreenshots screenshots allowed');
      notifyListeners();
      return;
    }

    final id = 'screenshot_${_screenshotIdCounter++}';
    final attachment = ScreenshotAttachment(
      id: id,
      localPath: localPath,
      status: UploadStatus.pending,
    );
    _screenshots.add(attachment);
    notifyListeners();

    // Start upload immediately
    await _uploadScreenshot(id);
  }

  /// Upload a screenshot to the server
  Future<void> _uploadScreenshot(String id) async {
    final index = _screenshots.indexWhere((s) => s.id == id);
    if (index == -1) return;

    // Update status to uploading
    _screenshots[index] = _screenshots[index].copyWith(
      status: UploadStatus.uploading,
      uploadProgress: 0.0,
    );
    notifyListeners();

    try {
      final file = File(_screenshots[index].localPath);
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      final url = await _apiService.uploadImage(file);
      if (url == null) {
        throw Exception('Upload returned no URL');
      }

      // Update with success
      final currentIndex = _screenshots.indexWhere((s) => s.id == id);
      if (currentIndex != -1) {
        _screenshots[currentIndex] = _screenshots[currentIndex].copyWith(
          status: UploadStatus.completed,
          uploadedUrl: url,
          uploadProgress: 1.0,
        );
        notifyListeners();
      }
    } catch (e) {
      // Update with failure
      final currentIndex = _screenshots.indexWhere((s) => s.id == id);
      if (currentIndex != -1) {
        _screenshots[currentIndex] = _screenshots[currentIndex].copyWith(
          status: UploadStatus.failed,
          error: e.toString(),
        );
        notifyListeners();
      }
    }
  }

  /// Retry uploading a failed screenshot
  Future<void> retryScreenshot(String id) async {
    final index = _screenshots.indexWhere((s) => s.id == id);
    if (index == -1) return;

    if (_screenshots[index].canRetry) {
      await _uploadScreenshot(id);
    }
  }

  /// Remove a screenshot from the list
  void removeScreenshot(String id) {
    _screenshots.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Clear all screenshots
  void clearScreenshots() {
    _screenshots = [];
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearTitleBodyModifiedFlag() {
    _titleBodyModifiedByAI = false;
  }

  void clearForm() {
    _title = '';
    _body = '';
    _screenshots = [];
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
