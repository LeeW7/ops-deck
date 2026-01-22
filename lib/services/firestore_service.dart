import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_model.dart';

/// Service for real-time Firestore job updates
class FirestoreJobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of all jobs, ordered by start time descending
  Stream<List<Job>> watchJobs() {
    return _firestore
        .collection('jobs')
        .orderBy('start_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Job.fromFirestore(doc))
          .toList();
    });
  }

  /// Stream of active jobs only
  Stream<List<Job>> watchActiveJobs() {
    return _firestore
        .collection('jobs')
        .where('status', whereIn: ['pending', 'running', 'waiting_approval'])
        .orderBy('start_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Job.fromFirestore(doc))
          .toList();
    });
  }

  /// Stream a single job by ID
  Stream<Job?> watchJob(String jobId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Job.fromFirestore(doc);
    });
  }

  /// Get a single job by ID
  Future<Job?> getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (!doc.exists) return null;
    return Job.fromFirestore(doc);
  }

  /// Stream jobs for a specific issue
  Stream<List<Job>> watchJobsForIssue(String repo, int issueNum) {
    return _firestore
        .collection('jobs')
        .where('repo', isEqualTo: repo)
        .where('issue_num', isEqualTo: issueNum)
        .orderBy('start_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Job.fromFirestore(doc))
          .toList();
    });
  }

  /// Get jobs for a specific issue (one-time fetch)
  Future<List<Job>> getJobsForIssue(String repo, int issueNum) async {
    final snapshot = await _firestore
        .collection('jobs')
        .where('repo', isEqualTo: repo)
        .where('issue_num', isEqualTo: issueNum)
        .orderBy('start_time', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Job.fromFirestore(doc))
        .toList();
  }

  /// Get costs for an issue (sum of all job costs)
  Future<Map<String, dynamic>> getCostsForIssue(String repo, int issueNum) async {
    final jobs = await getJobsForIssue(repo, issueNum);

    double totalCost = 0;
    int totalInputTokens = 0;
    int totalOutputTokens = 0;
    int totalCacheRead = 0;
    int totalCacheCreation = 0;

    for (final job in jobs) {
      final cost = job.cost;
      if (cost != null) {
        totalCost += cost.totalUsd;
        totalInputTokens += cost.inputTokens;
        totalOutputTokens += cost.outputTokens;
        totalCacheRead += cost.cacheReadTokens;
        totalCacheCreation += cost.cacheCreationTokens;
      }
    }

    return {
      'total_cost_usd': totalCost,
      'input_tokens': totalInputTokens,
      'output_tokens': totalOutputTokens,
      'cache_read_tokens': totalCacheRead,
      'cache_creation_tokens': totalCacheCreation,
      'job_count': jobs.length,
    };
  }

  /// Stream daily analytics
  Stream<Map<String, dynamic>?> watchDailyAnalytics(String date) {
    return _firestore
        .collection('analytics')
        .doc('default')
        .collection('daily')
        .doc(date)
        .snapshots()
        .map((doc) => doc.data());
  }

  /// Get analytics for a date range
  Future<List<Map<String, dynamic>>> getAnalyticsRange(
    DateTime start,
    DateTime end,
  ) async {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);

    final snapshot = await _firestore
        .collection('analytics')
        .doc('default')
        .collection('daily')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['date'] = doc.id;
      return data;
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
