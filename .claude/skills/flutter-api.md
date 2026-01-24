---
description: HTTP API service patterns with retry logic and error handling for Ops Deck
---

# API Service Development

## When to Use
- Adding new API endpoints
- Modifying HTTP request handling
- Implementing retry logic
- Adding typed error handling

## Patterns

### GET Request with Retry
```dart
Future<http.Response> _getWithRetry(
  String endpoint, {
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = 2,
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
      await Future.delayed(Duration(milliseconds: 500 * attempts));
    } on SocketException catch (e) {
      if (attempts > maxRetries) throw ApiException.network(e);
      await Future.delayed(Duration(milliseconds: 500 * attempts));
    }
  }
}
```

### POST Request (No Retry for Mutations)
```dart
Future<http.Response> _postWithRetry(
  String endpoint, {
  Map<String, dynamic>? body,
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = 2,
}) async {
  // Same pattern as GET but with body
}

// Usage - no retry to avoid duplicates
Future<Map<String, dynamic>> createResource(Map<String, dynamic> data) async {
  final response = await _postWithRetry(
    '/resource',
    body: data,
    maxRetries: 0, // Don't retry mutations
  );
  // ...
}
```

### Typed Error Handling
```dart
enum ApiErrorType {
  network,       // Connection failed
  timeout,       // Request timed out
  serverError,   // 5xx errors
  notFound,      // 404
  conflict,      // 409 (duplicate)
  unauthorized,  // 401/403
  badRequest,    // 400
  invalidJson,   // Parse failure
  notConfigured, // No server URL
  unknown,
}

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

  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.serverError;
}
```

### Response Handling Pattern
```dart
Future<List<MyModel>> fetchItems() async {
  final response = await _getWithRetry('/api/items');

  if (response.statusCode == 200) {
    final data = _parseJson(response) as List<dynamic>;
    return data.map((item) => MyModel.fromJson(item)).toList();
  } else {
    throw _handleErrorResponse(response, 'fetch items');
  }
}

dynamic _parseJson(http.Response response) {
  try {
    return json.decode(response.body);
  } on FormatException catch (e) {
    throw ApiException.invalidJson(e);
  }
}

ApiException _handleErrorResponse(http.Response response, [String? context]) {
  try {
    final data = json.decode(response.body);
    final serverMessage = data['reason'] ?? data['error']?.toString();
    return ApiException.fromStatusCode(response.statusCode, serverMessage);
  } catch (_) {
    return ApiException.fromStatusCode(response.statusCode);
  }
}
```

### Handle 409 Conflict Specifically
```dart
if (response.statusCode == 409) {
  final data = _parseJson(response);
  throw ApiException(
    data['reason'] ?? 'Resource already exists',
    type: ApiErrorType.conflict,
    statusCode: 409,
  );
}
```

## Best Practices

1. **Check configuration first** - Always verify base URL is set
2. **Retry GET requests** - Use exponential backoff (delay * attempts)
3. **Don't retry mutations** - POST/PUT with `maxRetries: 0`
4. **Parse server errors** - Extract `reason` or `error` from response
5. **Use longer timeouts for AI** - AI endpoints may need 60+ seconds
6. **Handle 409 specifically** - Duplicate prevention is critical

## Common Tasks

### Adding a New Endpoint
```dart
Future<MyModel> fetchItem(String id) async {
  final response = await _getWithRetry('/api/items/$id');

  if (response.statusCode == 200) {
    final data = _parseJson(response) as Map<String, dynamic>;
    return MyModel.fromJson(data);
  } else if (response.statusCode == 404) {
    throw ApiException('Item not found', type: ApiErrorType.notFound);
  } else {
    throw _handleErrorResponse(response, 'fetch item');
  }
}
```

### Adding File Upload
```dart
Future<String?> uploadFile(File file) async {
  final baseUrl = await getBaseUrl();
  if (baseUrl == null) throw ApiException.notConfigured();

  final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
  request.files.add(await http.MultipartFile.fromPath('file', file.path));

  final streamedResponse = await request.send().timeout(
    const Duration(seconds: 60),
  );
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    final data = _parseJson(response);
    return data['url'] as String?;
  }
  throw _handleErrorResponse(response, 'upload file');
}
```
