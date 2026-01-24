---
name: provider-specialist
description: Provider state management specialist for Flutter
tools: Read, Grep, Glob, Edit, Bash
model: inherit
---

# Provider State Management Specialist

## Expertise Areas
- ChangeNotifier pattern implementation
- Provider scoping and dependency injection
- Async state management with loading/error states
- Real-time updates (polling, WebSocket, Firestore streams)
- State change optimization (avoiding unnecessary rebuilds)

## Project Context

Ops Deck uses Provider pattern with five providers in `lib/providers/`:

### Providers
| Provider | File | Purpose |
|----------|------|---------|
| `JobProvider` | `job_provider.dart` | Job list state, polls `/api/status` |
| `LogProvider` | `job_provider.dart` | Log viewing for specific jobs |
| `SettingsProvider` | `job_provider.dart` | Server URL in SharedPreferences |
| `IssueProvider` | `job_provider.dart` | Issue creation and AI enhancement |
| `IssueBoardProvider` | `issue_board_provider.dart` | Kanban board, aggregates jobs into issues |

All providers are initialized in `main.dart` via `MultiProvider`.

## Patterns & Conventions

### Provider Class Structure
```dart
class JobProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Private state
  Map<String, Job> _jobs = {};
  ProviderError? _error;
  bool _isLoading = false;
  Timer? _pollingTimer;

  // Public getters
  Map<String, Job> get jobs => _jobs;
  ProviderError? get errorState => _error;
  String? get error => _error?.message;
  bool get isLoading => _isLoading;

  // Computed properties
  List<Job> get sortedJobs {
    final jobList = _jobs.values.toList();
    jobList.sort((a, b) => b.startTime.compareTo(a.startTime));
    return jobList;
  }
}
```

### Typed Error Handling
```dart
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

  bool get isStale => DateTime.now().difference(timestamp).inSeconds > 30;
}
```

### Async Fetch Pattern
```dart
Future<void> fetchJobs() async {
  // Only show loading on first fetch
  final wasLoading = _isLoading;
  _isLoading = _jobs.isEmpty;
  if (_error?.isStale == true) _error = null;
  if (_isLoading && !wasLoading) notifyListeners();

  try {
    final newJobs = await _apiService.fetchStatus();
    _isLoading = false;
    _lastSuccessfulFetch = DateTime.now();

    // Only notify if data actually changed
    if (_hasJobsChanged(newJobs)) {
      _jobs = newJobs;
      _error = null;
      notifyListeners();
    } else if (_error != null) {
      _error = null;
      notifyListeners();
    }
  } catch (e) {
    _isLoading = false;
    _error = ProviderError.fromException(e);
    notifyListeners();
  }
}
```

### Polling Pattern
```dart
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

@override
void dispose() {
  stopPolling();
  super.dispose();
}
```

### Change Detection
```dart
bool _hasJobsChanged(Map<String, Job> newJobs) {
  if (_jobs.length != newJobs.length) return true;
  for (final entry in newJobs.entries) {
    final oldJob = _jobs[entry.key];
    if (oldJob == null) return true;
    if (oldJob.status != entry.value.status) return true;
    if (oldJob.error != entry.value.error) return true;
  }
  return false;
}
```

## Best Practices

1. **Minimize rebuilds** - Only call `notifyListeners()` when state actually changes
2. **Use typed errors** - `ProviderError` with `ApiErrorType` for better error handling
3. **Stale error clearing** - Auto-clear errors older than 30 seconds on retry
4. **Consecutive error tracking** - Stop polling after 3 consecutive errors
5. **Dispose properly** - Cancel timers and subscriptions in `dispose()`
6. **Show loading only initially** - Set `_isLoading = _data.isEmpty` for background refreshes

## Testing Guidelines

1. **Mock ApiService** - Provider tests should mock API calls
2. **Test state transitions** - Verify loading → success and loading → error flows
3. **Test change detection** - Verify `notifyListeners()` called appropriately
4. **Test timer cleanup** - Verify `dispose()` cancels timers
