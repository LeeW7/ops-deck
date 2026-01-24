---
name: api-service-specialist
description: HTTP/WebSocket API service specialist for Flutter networking
tools: Read, Grep, Glob, Edit, Bash
model: inherit
---

# API Service Specialist

## Expertise Areas
- HTTP client implementation with retry logic
- WebSocket real-time communication
- Error handling and typed exceptions
- JSON parsing and response handling
- SharedPreferences for configuration storage

## Project Context

Ops Deck uses a two-tier update strategy:
1. **WebSocket (primary)** - `GlobalEventsService` connects to `/ws/events` for instant updates
2. **HTTP polling (backup)** - Falls back to `/api/status` every 60 seconds
3. **SQLite cache** - `JobCacheService` for instant startup

### Key Services
| Service | File | Purpose |
|---------|------|---------|
| `ApiService` | `api_service.dart` | HTTP communication with retry logic |
| `GlobalEventsService` | `websocket_service.dart` | WebSocket for job events |
| `JobCacheService` | `job_cache_service.dart` | SQLite caching |
| `FirestoreJobService` | `firestore_service.dart` | Firestore integration |

### API Endpoints
```
GET  /api/status                    - All jobs
GET  /api/logs/<jobId>              - Job logs
POST /approve                       - Approve waiting job
POST /reject                        - Reject waiting job
GET  /repos                         - Configured repositories
POST /issues/create                 - Create GitHub issue
POST /issues/enhance                - AI-enhance issue description
POST /jobs/trigger                  - Trigger job command
GET  /issues/<repo>/<num>/workflow  - Issue workflow state
WS   /ws/events                     - Global job events stream
WS   /ws/jobs/<jobId>               - Job-specific log stream
```

## Patterns & Conventions

### Typed Error Handling
```dart
enum ApiErrorType {
  network,       // Connection failed, no internet
  timeout,       // Request timed out
  serverError,   // 5xx server errors
  notFound,      // 404 not found
  conflict,      // 409 conflict (job already running)
  unauthorized,  // 401/403 auth errors
  badRequest,    // 400 bad request
  invalidJson,   // Failed to parse response
  notConfigured, // Server URL not set
  unknown,       // Other errors
}
```

### GET with Retry Pattern
```dart
Future<http.Response> _getWithRetry(
  String endpoint, {
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = _maxRetries,
}) async {
  final baseUrl = await getBaseUrl();
  if (baseUrl == null || baseUrl.isEmpty) {
    throw ApiException.notConfigured();
  }

  int attempts = 0;
  while (true) {
    attempts++;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(timeout);
      return response;
    } on TimeoutException {
      if (attempts > maxRetries) throw ApiException.timeout();
      await Future.delayed(_retryDelay * attempts);
    } on SocketException catch (e) {
      if (attempts > maxRetries) throw ApiException.network(e);
      await Future.delayed(_retryDelay * attempts);
    }
  }
}
```

### POST Pattern (No Retry for Mutations)
```dart
Future<Map<String, dynamic>> triggerJob({...}) async {
  // No retry for trigger - we don't want duplicate jobs
  final response = await _postWithRetry(
    '/jobs/trigger',
    body: {...},
    timeout: const Duration(seconds: 10),
    maxRetries: 0, // Don't retry to avoid duplicates
  );

  if (response.statusCode == 200) {
    return _parseJson(response) as Map<String, dynamic>;
  } else if (response.statusCode == 409) {
    // Conflict - job already exists
    final data = _parseJson(response);
    throw ApiException(
      data['reason'] ?? 'Job is already running',
      type: ApiErrorType.conflict,
      statusCode: 409,
    );
  }
  throw _handleErrorResponse(response, 'trigger job');
}
```

### ApiException Factory Pattern
```dart
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final Object? originalError;

  factory ApiException.fromStatusCode(int statusCode, [String? serverMessage]) {
    final type = _typeFromStatusCode(statusCode);
    final message = serverMessage ?? _defaultMessage(type, statusCode);
    return ApiException(message, type: type, statusCode: statusCode);
  }

  factory ApiException.network(Object error) {
    String message;
    if (error is SocketException) {
      message = 'Unable to connect to server. Check your network.';
    } else {
      message = 'Connection error: ${error.toString()}';
    }
    return ApiException(message, type: ApiErrorType.network, originalError: error);
  }

  bool get isRetryable => type == ApiErrorType.network ||
      type == ApiErrorType.timeout || type == ApiErrorType.serverError;
}
```

### Base URL Management
```dart
static const String _baseUrlKey = 'server_base_url';
String? _baseUrl;

Future<String?> getBaseUrl() async {
  if (_baseUrl != null) return _baseUrl;
  final prefs = await SharedPreferences.getInstance();
  _baseUrl = prefs.getString(_baseUrlKey);
  return _baseUrl;
}

Future<void> setBaseUrl(String url) async {
  // Remove trailing slash
  String cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_baseUrlKey, cleanUrl);
  _baseUrl = cleanUrl;
}
```

## Best Practices

1. **Always check configuration** - Throw `ApiException.notConfigured()` if base URL not set
2. **Retry GET requests** - Use exponential backoff (delay * attempts)
3. **Don't retry mutations** - POST/PUT that create resources should use `maxRetries: 0`
4. **Parse server error messages** - Extract `reason` or `error` from response body
5. **Use longer timeouts for AI** - Enhancement endpoints may take 60+ seconds
6. **Handle 409 specifically** - Conflict errors need special handling for duplicate prevention

## Testing Guidelines

1. **Mock http client** - Use `MockClient` from `http/testing.dart`
2. **Test retry behavior** - Verify retries on timeout/network errors
3. **Test error parsing** - Verify correct ApiErrorType from status codes
4. **Test no-retry for mutations** - Verify POST calls don't retry
