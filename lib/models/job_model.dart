enum JobStatus { running, failed, pending, completed, waitingApproval, rejected, unknown }

class Job {
  final String issueId;
  final String status;
  final String command;
  final int startTime;
  final String? error;
  final String repo;
  final String issueTitle;
  final int issueNum;

  Job({
    required this.issueId,
    required this.status,
    required this.command,
    required this.startTime,
    this.error,
    required this.repo,
    required this.issueTitle,
    required this.issueNum,
  });

  factory Job.fromJson(String issueId, Map<String, dynamic> json) {
    // Handle start_time as either int or double from JSON
    final rawStartTime = json['start_time'];
    final int startTime;
    if (rawStartTime is int) {
      startTime = rawStartTime;
    } else if (rawStartTime is double) {
      startTime = rawStartTime.toInt();
    } else {
      startTime = 0;
    }

    return Job(
      issueId: issueId,
      status: json['status'] as String? ?? 'unknown',
      command: json['command'] as String? ?? 'unknown',  // Use command name, not full cmd
      startTime: startTime,
      error: json['error'] as String?,
      repo: json['repo'] as String? ?? 'unknown',
      issueTitle: json['issue_title'] as String? ?? '',
      issueNum: json['issue_num'] as int? ?? 0,
    );
  }

  JobStatus get jobStatus {
    switch (status.toLowerCase()) {
      case 'running':
        return JobStatus.running;
      case 'failed':
        return JobStatus.failed;
      case 'pending':
        return JobStatus.pending;
      case 'completed':
        return JobStatus.completed;
      case 'waiting_approval':
        return JobStatus.waitingApproval;
      case 'rejected':
        return JobStatus.rejected;
      default:
        return JobStatus.unknown;
    }
  }

  bool get needsApproval => jobStatus == JobStatus.waitingApproval;

  DateTime get startDateTime {
    return DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
  }

  String get formattedStartTime {
    final dt = startDateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  static Map<String, Job> parseStatusResponse(dynamic json) {
    final Map<String, Job> jobs = {};

    if (json is List) {
      // Handle array response: [{"issue_id": "123", ...}, ...]
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          final issueId = (item['issue_id'] ?? item['issueId'] ?? '').toString();
          if (issueId.isNotEmpty) {
            jobs[issueId] = Job.fromJson(issueId, item);
          }
        }
      }
    } else if (json is Map<String, dynamic>) {
      // Handle object response: {"123": {...}, "456": {...}}
      json.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          jobs[key] = Job.fromJson(key, value);
        }
      });
    }

    return jobs;
  }
}
