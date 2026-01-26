import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';

/// Types of API errors for better error handling
enum ApiErrorType {
  network,       // Connection failed, no internet
  timeout,       // Request timed out
  serverError,   // 5xx server errors
  notFound,      // 404 not found
  conflict,      // 409 conflict (e.g., job already running)
  unauthorized,  // 401/403 auth errors
  badRequest,    // 400 bad request
  invalidJson,   // Failed to parse response
  notConfigured, // Server URL not set
  unknown,       // Other errors
}

class ApiService {
  static const String _baseUrlKey = 'server_base_url';
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  String? _baseUrl;

  Future<String?> getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey);
    return _baseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    // Remove trailing slash if present
    String cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, cleanUrl);
    _baseUrl = cleanUrl;
  }

  /// Make a GET request with retry logic for transient failures
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
        if (attempts > maxRetries) {
          throw ApiException.timeout();
        }
        await Future.delayed(_retryDelay * attempts);
      } on SocketException catch (e) {
        if (attempts > maxRetries) {
          throw ApiException.network(e);
        }
        await Future.delayed(_retryDelay * attempts);
      } catch (e) {
        if (e is ApiException) rethrow;
        if (attempts > maxRetries) {
          throw ApiException.network(e);
        }
        await Future.delayed(_retryDelay * attempts);
      }
    }
  }

  /// Make a POST request with retry logic for transient failures
  Future<http.Response> _postWithRetry(
    String endpoint, {
    Map<String, dynamic>? body,
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
            .post(
              Uri.parse('$baseUrl$endpoint'),
              headers: {'Content-Type': 'application/json'},
              body: body != null ? json.encode(body) : null,
            )
            .timeout(timeout);
        return response;
      } on TimeoutException {
        if (attempts > maxRetries) {
          throw ApiException.timeout();
        }
        await Future.delayed(_retryDelay * attempts);
      } on SocketException catch (e) {
        if (attempts > maxRetries) {
          throw ApiException.network(e);
        }
        await Future.delayed(_retryDelay * attempts);
      } catch (e) {
        if (e is ApiException) rethrow;
        if (attempts > maxRetries) {
          throw ApiException.network(e);
        }
        await Future.delayed(_retryDelay * attempts);
      }
    }
  }

  /// Parse JSON response with error handling
  dynamic _parseJson(http.Response response) {
    try {
      return json.decode(response.body);
    } on FormatException catch (e) {
      throw ApiException.invalidJson(e);
    }
  }

  /// Handle error response from server
  ApiException _handleErrorResponse(http.Response response, [String? context]) {
    try {
      final data = json.decode(response.body);
      final serverMessage = data['reason'] ?? data['error']?.toString();
      return ApiException.fromStatusCode(response.statusCode, serverMessage);
    } catch (_) {
      return ApiException.fromStatusCode(response.statusCode);
    }
  }

  Future<Map<String, Job>> fetchStatus() async {
    final response = await _getWithRetry('/api/status');

    if (response.statusCode == 200) {
      final decoded = _parseJson(response);
      return Job.parseStatusResponse(decoded);
    } else {
      throw _handleErrorResponse(response, 'fetch status');
    }
  }

  Future<String> fetchLogs(String issueId) async {
    final response = await _getWithRetry('/api/logs/$issueId');

    if (response.statusCode == 200) {
      final data = _parseJson(response) as Map<String, dynamic>;
      return data['logs'] as String? ?? '';
    } else {
      throw _handleErrorResponse(response, 'fetch logs');
    }
  }

  Future<bool> testConnection(String url) async {
    try {
      String cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final response = await http
          .get(Uri.parse('$cleanUrl/api/status'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveJob(String jobId) async {
    final response = await _postWithRetry(
      '/approve',
      body: {'job_id': jobId},
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw _handleErrorResponse(response, 'approve job');
    }
  }

  Future<bool> rejectJob(String jobId) async {
    final response = await _postWithRetry(
      '/reject',
      body: {'job_id': jobId},
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw _handleErrorResponse(response, 'reject job');
    }
  }

  Future<List<Map<String, String>>> fetchRepos() async {
    final response = await _getWithRetry('/repos');

    if (response.statusCode == 200) {
      final List<dynamic> data = _parseJson(response) as List<dynamic>;
      return data.map((repo) => {
        'name': repo['name'] as String,
        'full_name': repo['full_name'] as String,
        'path': repo['path'] as String,
      }).toList();
    } else {
      throw _handleErrorResponse(response, 'fetch repos');
    }
  }

  Future<Map<String, String>> enhanceIssue(String title, String description, String? repo) async {
    // Use description if provided, otherwise use title as the starting point
    final idea = description.isNotEmpty ? description : title;

    // No retry for AI enhancement - can be slow and shouldn't duplicate
    final response = await _postWithRetry(
      '/issues/enhance',
      body: {
        'idea': idea,
        'title': title,
        if (repo != null) 'repo': repo,
      },
      timeout: const Duration(seconds: 60), // Longer timeout for AI
      maxRetries: 0,
    );

    if (response.statusCode == 200) {
      final data = _parseJson(response);
      return {
        'title': data['enhanced_title'] as String? ?? title,
        'body': data['enhanced_body'] as String? ?? '',
      };
    } else {
      throw _handleErrorResponse(response, 'enhance issue');
    }
  }

  Future<Map<String, dynamic>> fetchIssueDetails(String repo, int issueNum) async {
    final response = await _getWithRetry(
      '/issues/$repo/$issueNum',
      timeout: const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'fetch issue details');
    }
  }

  Future<Map<String, dynamic>> proceedWithIssue(String repo, int issueNum) async {
    final response = await _postWithRetry(
      '/issues/$repo/$issueNum/proceed',
      timeout: const Duration(seconds: 30),
      maxRetries: 0, // Don't retry to avoid duplicate jobs
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'proceed with issue');
    }
  }

  /// Trigger a job directly - simple endpoint that returns immediately
  Future<Map<String, dynamic>> triggerJob({
    required String repo,
    required int issueNum,
    required String issueTitle,
    required String command,
    String? cmdLabel,
  }) async {
    // No retry for trigger - we don't want duplicate jobs
    final response = await _postWithRetry(
      '/jobs/trigger',
      body: {
        'repo': repo,
        'issueNum': issueNum,
        'issueTitle': issueTitle,
        'command': command,
        if (cmdLabel != null) 'cmdLabel': cmdLabel,
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 0, // Don't retry trigger to avoid duplicates
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else if (response.statusCode == 409) {
      // Job already exists - use specific error type
      final data = _parseJson(response);
      throw ApiException(
        data['reason'] ?? 'Job is already running or pending',
        type: ApiErrorType.conflict,
        statusCode: 409,
      );
    } else {
      throw _handleErrorResponse(response, 'trigger job');
    }
  }

  Future<Map<String, dynamic>> fetchWorkflowState(String repo, int issueNum) async {
    final response = await _getWithRetry('/issues/$repo/$issueNum/workflow');

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'fetch workflow state');
    }
  }

  Future<String> createIssue(String repo, String title, String body) async {
    final response = await _postWithRetry(
      '/issues/create',
      body: {
        'repo': repo,
        'title': title,
        'body': body,
      },
      timeout: const Duration(seconds: 30), // GitHub CLI can be slow
      maxRetries: 0, // Don't retry create to avoid duplicates
    );

    if (response.statusCode == 201) {
      final data = _parseJson(response);
      return data['issue_url'] as String? ?? 'Issue created';
    } else {
      throw _handleErrorResponse(response, 'create issue');
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException.notConfigured();
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/images/upload'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = _parseJson(response);
        // Return the gist URL (the image is embedded in the gist markdown)
        return data['url'] as String?;
      } else {
        throw _handleErrorResponse(response, 'upload image');
      }
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException catch (e) {
      throw ApiException.network(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e);
    }
  }

  Future<Map<String, dynamic>> postFeedback(
    String repo,
    int issueNum,
    String feedback, {
    String? imageUrl,
  }) async {
    final response = await _postWithRetry(
      '/issues/$repo/$issueNum/feedback',
      body: {
        'feedback': feedback,
        if (imageUrl != null) 'image_url': imageUrl,
      },
      timeout: const Duration(seconds: 15),
      maxRetries: 0, // Don't retry feedback to avoid duplicates
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'post feedback');
    }
  }

  Future<Map<String, dynamic>> mergePr(
    String repo,
    int issueNum, {
    String method = 'squash',
  }) async {
    // No retry for merge to avoid issues
    final response = await _postWithRetry(
      '/issues/$repo/$issueNum/merge',
      body: {'method': method},
      maxRetries: 0,
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'merge PR');
    }
  }

  Future<Map<String, dynamic>> fetchPrDetails(String repo, int issueNum) async {
    final response = await _getWithRetry(
      '/issues/$repo/$issueNum/pr',
      timeout: const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      // No PR found - return indicator
      return {'has_pr': false};
    } else {
      throw _handleErrorResponse(response, 'fetch PR details');
    }
  }

  Future<Map<String, dynamic>> fetchIssueCosts(String repo, int issueNum) async {
    final response = await _getWithRetry('/issues/$repo/$issueNum/costs');

    if (response.statusCode == 200) {
      return _parseJson(response) as Map<String, dynamic>;
    } else {
      throw _handleErrorResponse(response, 'fetch costs');
    }
  }

  /// Close an issue on GitHub
  Future<void> closeIssue(String repo, int issueNum, {String reason = 'completed'}) async {
    final response = await _postWithRetry(
      '/issues/$repo/$issueNum/close',
      body: {'reason': reason},
      maxRetries: 0, // Don't retry destructive operations
    );

    if (response.statusCode == 200) {
      return;
    } else {
      throw _handleErrorResponse(response, 'close issue');
    }
  }
}

/// Typed API exception with error categorization
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final Object? originalError;

  ApiException(
    this.message, {
    this.type = ApiErrorType.unknown,
    this.statusCode,
    this.originalError,
  });

  /// Create exception from HTTP status code
  factory ApiException.fromStatusCode(int statusCode, [String? serverMessage]) {
    final type = _typeFromStatusCode(statusCode);
    final message = serverMessage ?? _defaultMessage(type, statusCode);
    return ApiException(message, type: type, statusCode: statusCode);
  }

  /// Create network error exception
  factory ApiException.network(Object error) {
    String message;
    if (error is SocketException) {
      message = 'Unable to connect to server. Check your network connection.';
    } else if (error is HttpException) {
      message = 'Network request failed: ${error.message}';
    } else {
      message = 'Connection error: ${error.toString()}';
    }
    return ApiException(message, type: ApiErrorType.network, originalError: error);
  }

  /// Create timeout exception
  factory ApiException.timeout() {
    return ApiException(
      'Request timed out. The server may be busy.',
      type: ApiErrorType.timeout,
    );
  }

  /// Create JSON parsing exception
  factory ApiException.invalidJson(Object error) {
    return ApiException(
      'Received invalid response from server',
      type: ApiErrorType.invalidJson,
      originalError: error,
    );
  }

  /// Create not configured exception
  factory ApiException.notConfigured() {
    return ApiException(
      'Server URL not configured. Go to Settings to configure.',
      type: ApiErrorType.notConfigured,
    );
  }

  static ApiErrorType _typeFromStatusCode(int statusCode) {
    if (statusCode >= 500) return ApiErrorType.serverError;
    switch (statusCode) {
      case 400:
        return ApiErrorType.badRequest;
      case 401:
      case 403:
        return ApiErrorType.unauthorized;
      case 404:
        return ApiErrorType.notFound;
      case 409:
        return ApiErrorType.conflict;
      default:
        return ApiErrorType.unknown;
    }
  }

  static String _defaultMessage(ApiErrorType type, int statusCode) {
    switch (type) {
      case ApiErrorType.serverError:
        return 'Server error ($statusCode). Please try again later.';
      case ApiErrorType.notFound:
        return 'Resource not found';
      case ApiErrorType.conflict:
        return 'Operation conflict - resource may already exist';
      case ApiErrorType.unauthorized:
        return 'Authentication required';
      case ApiErrorType.badRequest:
        return 'Invalid request';
      default:
        return 'Request failed ($statusCode)';
    }
  }

  /// User-friendly error message
  String get userMessage => message;

  /// Whether this error is likely transient and retry may help
  bool get isRetryable {
    return type == ApiErrorType.network ||
        type == ApiErrorType.timeout ||
        type == ApiErrorType.serverError;
  }

  @override
  String toString() => message;
}
