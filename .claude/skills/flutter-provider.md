---
description: Provider state management patterns for Ops Deck Flutter app
---

# Provider State Management

## When to Use
- Adding new providers for features
- Modifying existing provider logic
- Implementing async data fetching
- Adding real-time updates (polling/WebSocket)

## Patterns

### Provider Class Template
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class MyProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Private state
  List<MyModel> _items = [];
  ProviderError? _error;
  bool _isLoading = false;
  bool _isConfigured = false;
  Timer? _pollingTimer;
  DateTime? _lastSuccessfulFetch;

  // Public getters
  List<MyModel> get items => _items;
  ProviderError? get errorState => _error;
  String? get error => _error?.message;
  bool get isLoading => _isLoading;
  bool get isConfigured => _isConfigured;
  bool get canRetry => _error?.isRetryable ?? false;

  // Computed properties
  List<MyModel> get activeItems => _items.where((i) => i.isActive).toList();

  // Initialization
  Future<void> initialize() async {
    final baseUrl = await _apiService.getBaseUrl();
    _isConfigured = baseUrl != null && baseUrl.isNotEmpty;
    notifyListeners();
  }
}
```

### Typed Error Class
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

### Async Fetch with Change Detection
```dart
Future<void> fetchData() async {
  if (!_isConfigured) {
    _error = ProviderError(
      message: 'Server not configured. Go to Settings.',
      type: ApiErrorType.notConfigured,
    );
    notifyListeners();
    return;
  }

  try {
    // Only show loading on first fetch
    final wasLoading = _isLoading;
    _isLoading = _items.isEmpty;
    if (_error?.isStale == true) _error = null;
    if (_isLoading && !wasLoading) notifyListeners();

    final newItems = await _apiService.fetchData();
    _isLoading = false;
    _lastSuccessfulFetch = DateTime.now();

    // Only notify if data changed
    if (_hasDataChanged(newItems)) {
      _items = newItems;
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
  fetchData();
  _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    fetchData();
  });
}

void stopPolling() {
  _pollingTimer?.cancel();
  _pollingTimer = null;
}

void startRealTimeUpdates() {
  // Prefer WebSocket, fall back to polling
  if (_useWebSocket) {
    _startWebSocketListener();
  } else {
    startPolling();
  }
}

@override
void dispose() {
  stopPolling();
  super.dispose();
}
```

## Best Practices

1. **Minimize rebuilds** - Only `notifyListeners()` when state actually changes
2. **Use typed errors** - `ProviderError` with `ApiErrorType` for categorization
3. **Clear stale errors** - Auto-clear errors > 30 seconds old on retry
4. **Show loading only initially** - Use `_isLoading = _items.isEmpty`
5. **Dispose properly** - Cancel all timers and subscriptions
6. **Check configuration first** - Throw early if not configured

## Common Tasks

### Adding a New Provider
1. Create provider class with `ChangeNotifier`
2. Add to `MultiProvider` in `main.dart`
3. Initialize in screen's `initState` via `context.read<MyProvider>()`
4. Access in build via `Consumer<MyProvider>`

### Adding Polling
```dart
// In provider
void startPolling() { ... }
void stopPolling() { ... }

// In screen initState
provider.initialize().then((_) {
  if (provider.isConfigured) provider.startPolling();
});

// In screen dispose
context.read<MyProvider>().stopPolling();
```

### Adding Action Methods
```dart
Future<bool> performAction(String id) async {
  try {
    final result = await _apiService.doAction(id);
    if (result) {
      await fetchData(); // Refresh list
    }
    return result;
  } catch (e) {
    _error = ProviderError.fromException(e);
    notifyListeners();
    return false;
  }
}
```
