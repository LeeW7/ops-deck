import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/preview_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

/// Provider for managing preview deployments and test results
class PreviewProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Validation states keyed by issue key (e.g., "ops-deck-123")
  final Map<String, ValidationState> _validationStates = {};

  // Loading states
  final Set<String> _loadingIssues = {};
  final Set<String> _triggeringPreview = {};

  // Error tracking
  String? _error;

  // Getters
  String? get error => _error;

  /// Get validation state for an issue
  ValidationState? getValidationState(String issueKey) {
    return _validationStates[issueKey];
  }

  /// Check if an issue has a preview available
  bool hasPreview(String issueKey) {
    final state = _validationStates[issueKey];
    return state?.hasPreviewUrl ?? false;
  }

  /// Check if an issue's tests are all passing
  bool allTestsPassing(String issueKey) {
    final state = _validationStates[issueKey];
    return state?.allTestsPassing ?? false;
  }

  /// Check if an issue has test results
  bool hasTestResults(String issueKey) {
    final state = _validationStates[issueKey];
    return state != null && state.testResults.isNotEmpty;
  }

  /// Check if validation data is loading for an issue
  bool isLoading(String issueKey) => _loadingIssues.contains(issueKey);

  /// Check if preview is being triggered for an issue
  bool isTriggeringPreview(String issueKey) => _triggeringPreview.contains(issueKey);

  /// Get preview URL for an issue (web preview or mobile download)
  String? getPreviewUrl(String issueKey) {
    final state = _validationStates[issueKey];
    if (state?.preview == null) return null;
    return state!.preview!.previewUrl ?? state.preview!.downloadUrl;
  }

  /// Get test summary text for an issue (e.g., "45 passed, 2 failed")
  String? getTestSummary(String issueKey) {
    final state = _validationStates[issueKey];
    if (state == null || state.testResults.isEmpty) return null;

    final passed = state.totalPassed;
    final failed = state.totalFailed;
    final skipped = state.totalSkipped;

    final parts = <String>[];
    if (passed > 0) parts.add('$passed passed');
    if (failed > 0) parts.add('$failed failed');
    if (skipped > 0) parts.add('$skipped skipped');

    return parts.join(', ');
  }

  /// Fetch validation state for an issue from the server
  Future<ValidationState?> fetchValidationState(String repo, int issueNum) async {
    final repoSlug = repo.split('/').last;
    final issueKey = '$repoSlug-$issueNum';

    if (_loadingIssues.contains(issueKey)) {
      // Already loading
      return _validationStates[issueKey];
    }

    _loadingIssues.add(issueKey);
    _error = null;
    notifyListeners();

    try {
      final state = await _apiService.getPreviewState(repo, issueNum);
      _validationStates[issueKey] = state;
      _loadingIssues.remove(issueKey);
      notifyListeners();
      return state;
    } catch (e) {
      _loadingIssues.remove(issueKey);
      _error = e.toString();
      if (kDebugMode) {
        print('[PreviewProvider] Error fetching validation state: $e');
      }
      notifyListeners();
      return null;
    }
  }

  /// Trigger a preview deployment for an issue
  Future<PreviewDeployment?> triggerPreview(String repo, int issueNum) async {
    final repoSlug = repo.split('/').last;
    final issueKey = '$repoSlug-$issueNum';

    if (_triggeringPreview.contains(issueKey)) {
      // Already triggering
      return _validationStates[issueKey]?.preview;
    }

    _triggeringPreview.add(issueKey);
    _error = null;
    notifyListeners();

    try {
      final preview = await _apiService.triggerPreview(repo, issueNum);

      // Update local state with the new preview
      final existingState = _validationStates[issueKey] ?? ValidationState.empty(issueKey);
      _validationStates[issueKey] = existingState.copyWith(
        preview: preview,
        phase: ValidationPhase.deploying,
        lastUpdated: DateTime.now(),
      );

      _triggeringPreview.remove(issueKey);
      notifyListeners();
      return preview;
    } catch (e) {
      _triggeringPreview.remove(issueKey);
      _error = e.toString();
      if (kDebugMode) {
        print('[PreviewProvider] Error triggering preview: $e');
      }
      notifyListeners();
      return null;
    }
  }

  /// Fetch test results for an issue
  Future<List<TestResult>> fetchTestResults(String repo, int issueNum) async {
    final repoSlug = repo.split('/').last;
    final issueKey = '$repoSlug-$issueNum';

    try {
      final results = await _apiService.getTestResults(repo, issueNum);

      // Update local state
      final existingState = _validationStates[issueKey] ?? ValidationState.empty(issueKey);
      _validationStates[issueKey] = existingState.copyWith(
        testResults: results,
        lastUpdated: DateTime.now(),
      );

      notifyListeners();
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('[PreviewProvider] Error fetching test results: $e');
      }
      return [];
    }
  }

  /// Handle a preview-related WebSocket event
  void handlePreviewEvent(JobEvent event) {
    final repoSlug = event.job.repo.split('/').last;
    final issueKey = '$repoSlug-${event.job.issueNum}';

    if (kDebugMode) {
      print('[PreviewProvider] Received event: ${event.type} for $issueKey');
    }

    switch (event.type) {
      case JobEventType.previewStatusChanged:
        _handlePreviewStatusChanged(issueKey, event);
        break;
      case JobEventType.testResultsUpdated:
        _handleTestResultsUpdated(issueKey, event);
        break;
      default:
        // Not a preview event
        break;
    }
  }

  void _handlePreviewStatusChanged(String issueKey, JobEvent event) {
    final preview = event.job.preview;
    if (preview == null) return;

    final existingState = _validationStates[issueKey] ?? ValidationState.empty(issueKey);

    // Determine validation phase based on preview status
    ValidationPhase phase;
    switch (preview.status) {
      case PreviewStatus.pending:
        phase = ValidationPhase.pending;
        break;
      case PreviewStatus.deploying:
        phase = ValidationPhase.deploying;
        break;
      case PreviewStatus.ready:
        phase = existingState.allTestsPassing
            ? ValidationPhase.ready
            : ValidationPhase.deploying;
        break;
      case PreviewStatus.failed:
      case PreviewStatus.expired:
        phase = ValidationPhase.failed;
        break;
    }

    _validationStates[issueKey] = existingState.copyWith(
      preview: preview,
      phase: phase,
      lastUpdated: DateTime.now(),
    );

    notifyListeners();
  }

  void _handleTestResultsUpdated(String issueKey, JobEvent event) {
    final testResults = event.job.testResults;
    if (testResults == null) return;

    final existingState = _validationStates[issueKey] ?? ValidationState.empty(issueKey);

    // Determine phase based on test results
    ValidationPhase phase;
    final allPassing = testResults.every((r) => r.allPassed);
    if (!allPassing) {
      phase = ValidationPhase.failed;
    } else if (existingState.previewReady) {
      phase = ValidationPhase.ready;
    } else {
      phase = existingState.phase;
    }

    _validationStates[issueKey] = existingState.copyWith(
      testResults: testResults,
      phase: phase,
      lastUpdated: DateTime.now(),
    );

    notifyListeners();
  }

  /// Update validation state directly (for use by IssueBoardProvider)
  void updateValidationState(String issueKey, ValidationState state) {
    _validationStates[issueKey] = state;
    notifyListeners();
  }

  /// Clear validation state for an issue
  void clearValidationState(String issueKey) {
    _validationStates.remove(issueKey);
    _loadingIssues.remove(issueKey);
    _triggeringPreview.remove(issueKey);
    notifyListeners();
  }

  /// Clear all validation states
  void clearAll() {
    _validationStates.clear();
    _loadingIssues.clear();
    _triggeringPreview.clear();
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
