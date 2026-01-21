import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';

class JobProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreJobService _firestoreService = FirestoreJobService();

  Map<String, Job> _jobs = {};
  String? _error;
  bool _isLoading = false;
  bool _isConfigured = false;
  bool _useFirestore = false;
  Timer? _pollingTimer;
  StreamSubscription? _firestoreSubscription;

  Map<String, Job> get jobs => _jobs;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isConfigured => _isConfigured;
  bool get useFirestore => _useFirestore;

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
    try {
      // Test Firestore connection
      await FirebaseFirestore.instance
          .collection('jobs')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      _useFirestore = true;
      if (kDebugMode) {
        print('[JobProvider] Firestore available, using real-time updates');
      }
    } catch (e) {
      _useFirestore = false;
      if (kDebugMode) {
        print('[JobProvider] Firestore not available, falling back to HTTP polling: $e');
      }
    }
  }

  Future<void> checkConfiguration() async {
    final baseUrl = await _apiService.getBaseUrl();
    _isConfigured = baseUrl != null && baseUrl.isNotEmpty;
    notifyListeners();
  }

  /// Fetch jobs using HTTP API (fallback)
  Future<void> fetchJobs() async {
    if (!_isConfigured) {
      _error = 'Server not configured';
      notifyListeners();
      return;
    }

    try {
      _isLoading = _jobs.isEmpty;
      _error = null;
      if (_isLoading) notifyListeners();

      _jobs = await _apiService.fetchStatus();
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
      _error = e.toString();
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
      _error = e.toString();
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
  String? _error;
  bool _isLoading = false;
  Timer? _pollingTimer;
  String? _currentIssueId;

  String get logs => _logs;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> fetchLogs(String issueId) async {
    try {
      _isLoading = _logs.isEmpty;
      _error = null;
      if (_isLoading) notifyListeners();

      _logs = await _apiService.fetchLogs(issueId);
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void startPolling(String issueId) {
    stopPolling();
    _currentIssueId = issueId;
    _logs = '';
    _error = null;
    fetchLogs(issueId);
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  List<Map<String, String>> _repos = [];
  String? _selectedRepo;
  String _title = '';
  String _body = '';
  bool _isLoading = false;
  bool _isEnhancing = false;
  bool _isCreating = false;
  String? _error;
  String? _successMessage;

  List<Map<String, String>> get repos => _repos;
  String? get selectedRepo => _selectedRepo;
  String get title => _title;
  String get body => _body;
  bool get isLoading => _isLoading;
  bool get isEnhancing => _isEnhancing;
  bool get isCreating => _isCreating;
  String? get error => _error;
  String? get successMessage => _successMessage;

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
      _error = e.toString();
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
    notifyListeners();
  }

  void setBody(String body) {
    _body = body;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> enhanceWithAI() async {
    if (_title.isEmpty && _body.isEmpty) {
      _error = 'Please enter a title or description first';
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
      _isEnhancing = false;
      notifyListeners();
    } catch (e) {
      _isEnhancing = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createIssue() async {
    if (_selectedRepo == null || _selectedRepo!.isEmpty) {
      _error = 'Please select a repository';
      notifyListeners();
      return false;
    }
    if (_title.isEmpty) {
      _error = 'Please enter a title';
      notifyListeners();
      return false;
    }

    _isCreating = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final issueUrl = await _apiService.createIssue(_selectedRepo!, _title, _body);
      _isCreating = false;
      _successMessage = 'Issue created! $issueUrl';
      // Clear form
      _title = '';
      _body = '';
      notifyListeners();
      return true;
    } catch (e) {
      _isCreating = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearForm() {
    _title = '';
    _body = '';
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
