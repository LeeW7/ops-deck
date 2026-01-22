import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/models/job_model.dart';

void main() {
  group('Job', () {
    test('parses from JSON correctly', () {
      final json = {
        'status': 'running',
        'command': 'plan-headless',
        'start_time': 1705900000,
        'repo': 'owner/test-repo',
        'repo_slug': 'test-repo',
        'issue_title': 'Test Issue',
        'issue_num': 123,
        'log_path': '/tmp/log.txt',
        'local_path': '/Users/test/repo',
        'full_command': 'claude /plan-headless 123',
      };

      final job = Job.fromJson('test-repo-123-plan-headless', json);

      expect(job.issueId, 'test-repo-123-plan-headless');
      expect(job.status, 'running');
      expect(job.command, 'plan-headless');
      expect(job.startTime, 1705900000);
      expect(job.repo, 'owner/test-repo');
      expect(job.repoSlug, 'test-repo');
      expect(job.issueTitle, 'Test Issue');
      expect(job.issueNum, 123);
    });

    test('parses start_time as double', () {
      final json = {
        'status': 'completed',
        'command': 'implement-headless',
        'start_time': 1705900000.5, // double
        'repo': 'owner/repo',
        'repo_slug': 'repo',
        'issue_title': 'Title',
        'issue_num': 1,
        'log_path': '/tmp/log.txt',
        'local_path': '/path',
        'full_command': 'cmd',
      };

      final job = Job.fromJson('job-1', json);

      expect(job.startTime, 1705900000); // Should truncate to int
    });

    test('handles missing optional fields with defaults', () {
      final json = {
        'status': 'pending',
        'command': 'plan',
        'start_time': 1705900000,
      };

      final job = Job.fromJson('minimal-job', json);

      expect(job.issueId, 'minimal-job');
      expect(job.status, 'pending');
      expect(job.repo, 'unknown');
      expect(job.repoSlug, '');
      expect(job.issueTitle, '');
      expect(job.issueNum, 0);
      expect(job.cost, isNull);
      expect(job.error, isNull);
      expect(job.completedTime, isNull);
    });

    test('parses cost data correctly', () {
      final json = {
        'status': 'completed',
        'command': 'plan',
        'start_time': 1705900000,
        'repo': 'owner/repo',
        'repo_slug': 'repo',
        'issue_title': 'Title',
        'issue_num': 1,
        'log_path': '/tmp/log.txt',
        'local_path': '/path',
        'full_command': 'cmd',
        'cost': {
          'total_usd': 0.05,
          'input_tokens': 1000,
          'output_tokens': 500,
          'cache_read_tokens': 200,
          'cache_creation_tokens': 100,
          'model': 'claude-sonnet-4-20250514',
        },
      };

      final job = Job.fromJson('job-with-cost', json);

      expect(job.cost, isNotNull);
      expect(job.cost!.totalUsd, 0.05);
      expect(job.cost!.inputTokens, 1000);
      expect(job.cost!.outputTokens, 500);
      expect(job.cost!.cacheReadTokens, 200);
      expect(job.cost!.cacheCreationTokens, 100);
      expect(job.cost!.model, 'claude-sonnet-4-20250514');
    });

    group('jobStatus', () {
      test('maps running status', () {
        final job = _createJob('running');
        expect(job.jobStatus, JobStatus.running);
      });

      test('maps failed status', () {
        final job = _createJob('failed');
        expect(job.jobStatus, JobStatus.failed);
      });

      test('maps pending status', () {
        final job = _createJob('pending');
        expect(job.jobStatus, JobStatus.pending);
      });

      test('maps completed status', () {
        final job = _createJob('completed');
        expect(job.jobStatus, JobStatus.completed);
      });

      test('maps waiting_approval status', () {
        final job = _createJob('waiting_approval');
        expect(job.jobStatus, JobStatus.waitingApproval);
      });

      test('maps rejected status', () {
        final job = _createJob('rejected');
        expect(job.jobStatus, JobStatus.rejected);
      });

      test('maps interrupted status', () {
        final job = _createJob('interrupted');
        expect(job.jobStatus, JobStatus.interrupted);
      });

      test('maps approved_resume status', () {
        final job = _createJob('approved_resume');
        expect(job.jobStatus, JobStatus.approvedResume);
      });

      test('maps blocked status', () {
        final job = _createJob('blocked');
        expect(job.jobStatus, JobStatus.blocked);
      });

      test('maps unknown status for invalid value', () {
        final job = _createJob('some_invalid_status');
        expect(job.jobStatus, JobStatus.unknown);
      });

      test('is case insensitive', () {
        final job = _createJob('RUNNING');
        expect(job.jobStatus, JobStatus.running);
      });
    });

    group('computed properties', () {
      test('needsApproval is true for waiting_approval', () {
        final job = _createJob('waiting_approval');
        expect(job.needsApproval, true);
      });

      test('needsApproval is false for other statuses', () {
        final job = _createJob('running');
        expect(job.needsApproval, false);
      });

      test('needsAttention for blocked', () {
        final job = _createJob('blocked');
        expect(job.needsAttention, true);
      });

      test('needsAttention for failed', () {
        final job = _createJob('failed');
        expect(job.needsAttention, true);
      });

      test('needsAttention for waiting_approval', () {
        final job = _createJob('waiting_approval');
        expect(job.needsAttention, true);
      });

      test('needsAttention false for running', () {
        final job = _createJob('running');
        expect(job.needsAttention, false);
      });

      test('isActive for pending', () {
        final job = _createJob('pending');
        expect(job.isActive, true);
      });

      test('isActive for running', () {
        final job = _createJob('running');
        expect(job.isActive, true);
      });

      test('isActive for waiting_approval', () {
        final job = _createJob('waiting_approval');
        expect(job.isActive, true);
      });

      test('isActive false for completed', () {
        final job = _createJob('completed');
        expect(job.isActive, false);
      });

      test('shortCommand removes -headless suffix', () {
        final job = Job.fromJson('test', {
          'status': 'running',
          'command': 'plan-headless',
          'start_time': 1705900000,
        });
        expect(job.shortCommand, 'plan');
      });

      test('duration calculation', () {
        final json = {
          'status': 'completed',
          'command': 'plan',
          'start_time': 1000,
          'completed_time': 1060, // 60 seconds later
        };

        final job = Job.fromJson('test', json);
        expect(job.duration, Duration(seconds: 60));
        expect(job.formattedDuration, '1m 0s');
      });

      test('duration is null when not completed', () {
        final job = _createJob('running');
        expect(job.duration, isNull);
        expect(job.formattedDuration, isNull);
      });
    });

    group('parseStatusResponse', () {
      test('parses array response', () {
        final json = [
          {
            'issue_id': 'job-1',
            'status': 'running',
            'command': 'plan',
            'start_time': 1705900000,
          },
          {
            'issue_id': 'job-2',
            'status': 'completed',
            'command': 'implement',
            'start_time': 1705900100,
          },
        ];

        final jobs = Job.parseStatusResponse(json);

        expect(jobs.length, 2);
        expect(jobs['job-1']?.status, 'running');
        expect(jobs['job-2']?.status, 'completed');
      });

      test('parses object response', () {
        final json = {
          'job-1': {
            'status': 'running',
            'command': 'plan',
            'start_time': 1705900000,
          },
          'job-2': {
            'status': 'completed',
            'command': 'implement',
            'start_time': 1705900100,
          },
        };

        final jobs = Job.parseStatusResponse(json);

        expect(jobs.length, 2);
        expect(jobs['job-1']?.status, 'running');
        expect(jobs['job-2']?.status, 'completed');
      });

      test('handles empty array', () {
        final jobs = Job.parseStatusResponse([]);
        expect(jobs.isEmpty, true);
      });

      test('handles empty object', () {
        final jobs = Job.parseStatusResponse(<String, dynamic>{});
        expect(jobs.isEmpty, true);
      });
    });
  });

  group('JobCost', () {
    test('parses from map correctly', () {
      final map = {
        'total_usd': 0.123,
        'input_tokens': 5000,
        'output_tokens': 2500,
        'cache_read_tokens': 1000,
        'cache_creation_tokens': 500,
        'model': 'claude-sonnet-4-20250514',
      };

      final cost = JobCost.fromMap(map);

      expect(cost.totalUsd, 0.123);
      expect(cost.inputTokens, 5000);
      expect(cost.outputTokens, 2500);
      expect(cost.cacheReadTokens, 1000);
      expect(cost.cacheCreationTokens, 500);
      expect(cost.model, 'claude-sonnet-4-20250514');
    });

    test('handles missing values with defaults', () {
      final cost = JobCost.fromMap({});

      expect(cost.totalUsd, 0.0);
      expect(cost.inputTokens, 0);
      expect(cost.outputTokens, 0);
      expect(cost.cacheReadTokens, 0);
      expect(cost.cacheCreationTokens, 0);
      expect(cost.model, 'unknown');
    });

    test('formattedCost returns correct format', () {
      final cost = JobCost.fromMap({
        'total_usd': 0.1234,
        'input_tokens': 100,
        'output_tokens': 50,
        'model': 'test',
      });

      expect(cost.formattedCost, '\$0.1234');
    });

    test('totalTokens calculation', () {
      final cost = JobCost.fromMap({
        'total_usd': 0.1,
        'input_tokens': 1000,
        'output_tokens': 500,
        'model': 'test',
      });

      expect(cost.totalTokens, 1500);
    });

    test('cacheHitRate calculation', () {
      final cost = JobCost.fromMap({
        'total_usd': 0.1,
        'input_tokens': 1000,
        'output_tokens': 500,
        'cache_read_tokens': 200,
        'model': 'test',
      });

      expect(cost.cacheHitRate, 0.2); // 200/1000
    });

    test('cacheHitRate handles zero input tokens', () {
      final cost = JobCost.fromMap({
        'total_usd': 0.1,
        'input_tokens': 0,
        'output_tokens': 50,
        'cache_read_tokens': 100,
        'model': 'test',
      });

      expect(cost.cacheHitRate, 0);
    });
  });
}

// Helper to create a job with specific status
Job _createJob(String status) {
  return Job.fromJson('test-job', {
    'status': status,
    'command': 'plan-headless',
    'start_time': 1705900000,
  });
}
