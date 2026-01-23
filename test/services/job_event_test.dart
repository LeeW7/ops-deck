import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/services/websocket_service.dart';

void main() {
  group('JobEvent', () {
    test('parses jobCreated event from JSON', () {
      final json = {
        'type': 'jobCreated',
        'timestamp': '2024-01-22T10:30:00Z',
        'job': {
          'id': 'test-repo-123-plan-headless',
          'repo': 'owner/test-repo',
          'issueNum': 123,
          'issueTitle': 'Test Issue',
          'command': 'plan-headless',
          'status': 'pending',
          'cost': null,
        },
      };

      final event = JobEvent.fromJson(json);

      expect(event.type, JobEventType.jobCreated);
      expect(event.job.id, 'test-repo-123-plan-headless');
      expect(event.job.repo, 'owner/test-repo');
      expect(event.job.issueNum, 123);
      expect(event.job.issueTitle, 'Test Issue');
      expect(event.job.command, 'plan-headless');
      expect(event.job.status, 'pending');
      expect(event.job.cost, isNull);
    });

    test('parses jobStatusChanged event from JSON', () {
      final json = {
        'type': 'jobStatusChanged',
        'timestamp': '2024-01-22T10:31:00Z',
        'job': {
          'id': 'test-repo-123-plan-headless',
          'repo': 'owner/test-repo',
          'issueNum': 123,
          'issueTitle': 'Test Issue',
          'command': 'plan-headless',
          'status': 'running',
          'cost': null,
        },
      };

      final event = JobEvent.fromJson(json);

      expect(event.type, JobEventType.jobStatusChanged);
      expect(event.job.status, 'running');
    });

    test('parses jobCompleted event with cost data', () {
      final json = {
        'type': 'jobCompleted',
        'timestamp': '2024-01-22T10:45:00Z',
        'job': {
          'id': 'test-repo-123-plan-headless',
          'repo': 'owner/test-repo',
          'issueNum': 123,
          'issueTitle': 'Test Issue',
          'command': 'plan-headless',
          'status': 'completed',
          'cost': {
            'totalUsd': 0.05,
            'inputTokens': 1000,
            'outputTokens': 500,
          },
        },
      };

      final event = JobEvent.fromJson(json);

      expect(event.type, JobEventType.jobCompleted);
      expect(event.job.status, 'completed');
      expect(event.job.cost, isNotNull);
      expect(event.job.cost!.totalUsd, 0.05);
      expect(event.job.cost!.inputTokens, 1000);
      expect(event.job.cost!.outputTokens, 500);
    });

    test('parses jobFailed event', () {
      final json = {
        'type': 'jobFailed',
        'timestamp': '2024-01-22T10:40:00Z',
        'job': {
          'id': 'test-repo-456-implement-headless',
          'repo': 'owner/test-repo',
          'issueNum': 456,
          'issueTitle': 'Another Issue',
          'command': 'implement-headless',
          'status': 'failed',
          'cost': null,
        },
      };

      final event = JobEvent.fromJson(json);

      expect(event.type, JobEventType.jobFailed);
      expect(event.job.id, 'test-repo-456-implement-headless');
      expect(event.job.status, 'failed');
    });

    test('handles unknown event type gracefully', () {
      final json = {
        'type': 'someUnknownType',
        'timestamp': '2024-01-22T10:40:00Z',
        'job': {
          'id': 'test-repo-789-review',
          'repo': 'owner/test-repo',
          'issueNum': 789,
          'issueTitle': 'Unknown Type Test',
          'command': 'review',
          'status': 'pending',
          'cost': null,
        },
      };

      final event = JobEvent.fromJson(json);

      expect(event.type, JobEventType.unknown);
      expect(event.job.id, 'test-repo-789-review');
    });

    test('parses from JSON string correctly', () {
      final jsonString = '''
        {
          "type": "jobCreated",
          "timestamp": "2024-01-22T10:30:00Z",
          "job": {
            "id": "string-parse-test",
            "repo": "owner/repo",
            "issueNum": 1,
            "issueTitle": "String Parse Test",
            "command": "plan",
            "status": "pending",
            "cost": null
          }
        }
      ''';

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final event = JobEvent.fromJson(decoded);

      expect(event.job.id, 'string-parse-test');
    });
  });

  group('JobEventData', () {
    test('parses minimal job data', () {
      final json = {
        'id': 'minimal-job',
        'repo': 'owner/repo',
        'issueNum': 1,
        'issueTitle': 'Minimal',
        'command': 'plan',
        'status': 'pending',
      };

      final data = JobEventData.fromJson(json);

      expect(data.id, 'minimal-job');
      expect(data.cost, isNull);
    });

    test('parses complete job data with cost', () {
      final json = {
        'id': 'complete-job',
        'repo': 'owner/repo',
        'issueNum': 42,
        'issueTitle': 'Complete Job',
        'command': 'implement-headless',
        'status': 'completed',
        'cost': {
          'totalUsd': 1.23,
          'inputTokens': 5000,
          'outputTokens': 2500,
        },
      };

      final data = JobEventData.fromJson(json);

      expect(data.id, 'complete-job');
      expect(data.issueNum, 42);
      expect(data.cost, isNotNull);
      expect(data.cost!.totalUsd, 1.23);
    });
  });

  group('JobCostData', () {
    test('parses cost data correctly', () {
      final json = {
        'totalUsd': 0.123456,
        'inputTokens': 10000,
        'outputTokens': 5000,
      };

      final cost = JobCostData.fromJson(json);

      expect(cost.totalUsd, 0.123456);
      expect(cost.inputTokens, 10000);
      expect(cost.outputTokens, 5000);
    });

    test('handles missing values with defaults', () {
      final cost = JobCostData.fromJson({});

      expect(cost.totalUsd, 0);
      expect(cost.inputTokens, 0);
      expect(cost.outputTokens, 0);
    });

    test('handles integer totalUsd', () {
      final json = {
        'totalUsd': 1,
        'inputTokens': 100,
        'outputTokens': 50,
      };

      final cost = JobCostData.fromJson(json);

      expect(cost.totalUsd, 1.0);
    });
  });
}
