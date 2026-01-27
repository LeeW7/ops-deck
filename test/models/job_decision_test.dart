import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/models/job_model.dart';

void main() {
  group('JobDecision', () {
    test('fromJson parses complete decision', () {
      final json = {
        'id': 'dec-123',
        'action': 'Used Provider pattern',
        'reasoning': 'Matches existing codebase patterns',
        'alternatives': ['Riverpod', 'Bloc'],
        'category': 'architecture',
        'timestamp': '2024-01-27T10:30:00Z',
      };

      final decision = JobDecision.fromJson(json);

      expect(decision.id, 'dec-123');
      expect(decision.action, 'Used Provider pattern');
      expect(decision.reasoning, 'Matches existing codebase patterns');
      expect(decision.alternatives, ['Riverpod', 'Bloc']);
      expect(decision.category, 'architecture');
      expect(decision.categoryIcon, 'architecture');
    });

    test('fromJson handles minimal decision', () {
      final json = {
        'action': 'Created new service',
        'reasoning': 'Separation of concerns',
      };

      final decision = JobDecision.fromJson(json);

      expect(decision.id, '');
      expect(decision.action, 'Created new service');
      expect(decision.reasoning, 'Separation of concerns');
      expect(decision.alternatives, null);
      expect(decision.category, null);
      expect(decision.categoryIcon, 'other');
    });

    test('fromJson handles timestamp as milliseconds', () {
      final json = {
        'action': 'Test',
        'reasoning': 'Test reason',
        'timestamp': 1706300000000,
      };

      final decision = JobDecision.fromJson(json);

      expect(decision.timestamp.year, 2024);
    });

    test('categoryIcon returns correct icon for each category', () {
      final categories = {
        'architecture': 'architecture',
        'library': 'library',
        'pattern': 'pattern',
        'storage': 'storage',
        'api': 'api',
        'testing': 'testing',
        'unknown': 'other',
        null: 'other',
      };

      for (final entry in categories.entries) {
        final decision = JobDecision(
          id: 'test',
          action: 'test',
          reasoning: 'test',
          category: entry.key,
          timestamp: DateTime.now(),
        );
        expect(decision.categoryIcon, entry.value,
            reason: 'Category ${entry.key} should have icon ${entry.value}');
      }
    });
  });

  group('Job with decisions', () {
    test('parses decisions from JSON', () {
      final json = {
        'status': 'completed',
        'command': 'implement',
        'start_time': 1706300000,
        'repo': 'owner/repo',
        'repo_slug': 'repo',
        'issue_title': 'Test Issue',
        'issue_num': 123,
        'log_path': '/path/to/log',
        'local_path': '/path/to/local',
        'full_command': 'implement-headless',
        'decisions': [
          {
            'id': 'dec-1',
            'action': 'Used Provider',
            'reasoning': 'Matches existing patterns',
            'category': 'architecture',
          },
          {
            'id': 'dec-2',
            'action': 'Created service class',
            'reasoning': 'Separates concerns',
            'category': 'architecture',
          },
        ],
      };

      final job = Job.fromJson('test-job-id', json);

      expect(job.decisions.length, 2);
      expect(job.decisions[0].action, 'Used Provider');
      expect(job.decisions[1].action, 'Created service class');
    });

    test('handles missing decisions field', () {
      final json = {
        'status': 'completed',
        'command': 'implement',
        'start_time': 1706300000,
        'repo': 'owner/repo',
        'repo_slug': 'repo',
        'issue_title': 'Test Issue',
        'issue_num': 123,
        'log_path': '/path/to/log',
        'local_path': '/path/to/local',
        'full_command': 'implement-headless',
      };

      final job = Job.fromJson('test-job-id', json);

      expect(job.decisions, isEmpty);
    });

    test('handles null decisions field', () {
      final json = {
        'status': 'completed',
        'command': 'implement',
        'start_time': 1706300000,
        'repo': 'owner/repo',
        'repo_slug': 'repo',
        'issue_title': 'Test Issue',
        'issue_num': 123,
        'log_path': '/path/to/log',
        'local_path': '/path/to/local',
        'full_command': 'implement-headless',
        'decisions': null,
      };

      final job = Job.fromJson('test-job-id', json);

      expect(job.decisions, isEmpty);
    });
  });
}
