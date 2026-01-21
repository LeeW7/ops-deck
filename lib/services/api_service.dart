import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';

class ApiService {
  static const String _baseUrlKey = 'server_base_url';
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

  Future<Map<String, Job>> fetchStatus() async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return Job.parseStatusResponse(decoded);
      } else {
        throw ApiException('Failed to fetch status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<String> fetchLogs(String issueId) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/logs/$issueId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['logs'] as String? ?? '';
      } else {
        throw ApiException('Failed to fetch logs: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
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
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/approve'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'job_id': jobId}),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<bool> rejectJob(String jobId) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reject'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'job_id': jobId}),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<List<Map<String, String>>> fetchRepos() async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/repos'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((repo) => {
          'name': repo['name'] as String,
          'full_name': repo['full_name'] as String,
          'path': repo['path'] as String,
        }).toList();
      } else {
        throw ApiException('Failed to fetch repos: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, String>> enhanceIssue(String title, String description, String? repo) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    // Use description if provided, otherwise use title as the starting point
    final idea = description.isNotEmpty ? description : title;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues/enhance'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'idea': idea,
              'title': title,
              if (repo != null) 'repo': repo,
            }),
          )
          .timeout(const Duration(seconds: 30)); // Longer timeout for AI

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'title': data['enhanced_title'] as String? ?? title,
          'body': data['enhanced_body'] as String? ?? '',
        };
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to enhance issue');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchIssueDetails(String repo, int issueNum) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/issues/$repo/$issueNum'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to fetch issue details: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> proceedWithIssue(String repo, int issueNum) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(Uri.parse('$baseUrl/issues/$repo/$issueNum/proceed'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to proceed');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchWorkflowState(String repo, int issueNum) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/issues/$repo/$issueNum/workflow'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to fetch workflow state: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<String> createIssue(String repo, String title, String body) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'repo': repo,
              'title': title,
              'body': body,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['issue_url'] as String? ?? 'Issue created';
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to create issue');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
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
        final data = json.decode(response.body);
        // Return the gist URL (the image is embedded in the gist markdown)
        return data['url'] as String?;
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to upload image');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> postFeedback(
    String repo,
    int issueNum,
    String feedback, {
    String? imageUrl,
  }) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues/$repo/$issueNum/feedback'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'feedback': feedback,
              if (imageUrl != null) 'image_url': imageUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to post feedback');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> mergePr(
    String repo,
    int issueNum, {
    String method = 'squash',
  }) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues/$repo/$issueNum/merge'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'method': method}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final data = json.decode(response.body);
        throw ApiException(data['reason'] ?? data['error']?.toString() ?? 'Failed to merge PR');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchPrDetails(String repo, int issueNum) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ApiException('Server URL not configured');
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/issues/$repo/$issueNum/pr'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // No PR found - return indicator
        return {'has_pr': false};
      } else {
        throw ApiException('Failed to fetch PR details: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
