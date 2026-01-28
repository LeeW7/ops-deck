import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/models/job_model.dart';

void main() {
  group('JobConfidence', () {
    test('fromJson parses complete confidence', () {
      final json = {
        'score': 0.85,
        'assessment': 'HIGH',
        'reasoning': 'Straightforward feature using established patterns',
        'risks': 'None identified',
      };

      final confidence = JobConfidence.fromJson(json);

      expect(confidence.score, 0.85);
      expect(confidence.assessment, 'HIGH');
      expect(confidence.reasoning, 'Straightforward feature using established patterns');
      expect(confidence.risks, 'None identified');
    });

    test('fromJson handles minimal confidence', () {
      final json = {
        'score': 0.5,
        'reasoning': 'Some complexity involved',
      };

      final confidence = JobConfidence.fromJson(json);

      expect(confidence.score, 0.5);
      expect(confidence.assessment, 'MEDIUM');
      expect(confidence.reasoning, 'Some complexity involved');
      expect(confidence.risks, null);
    });

    test('fromJson clamps score to valid range', () {
      expect(JobConfidence.fromJson({'score': -0.5}).score, 0.0);
      expect(JobConfidence.fromJson({'score': 0.75}).score, 0.75);
      expect(JobConfidence.fromJson({'score': 150}).score, 1.0); // 150% clamped
    });

    test('fromJson handles 0-100 scale scores', () {
      expect(JobConfidence.fromJson({'score': 95}).score, 0.95);
      expect(JobConfidence.fromJson({'score': 85.5}).score, 0.855);
      expect(JobConfidence.fromJson({'score': 50}).score, 0.50);
    });

    test('fromJson handles string score', () {
      final confidence = JobConfidence.fromJson({'score': '0.65'});
      expect(confidence.score, 0.65);
    });

    test('fromJson handles int score', () {
      final confidence = JobConfidence.fromJson({'score': 1});
      expect(confidence.score, 1.0);
    });

    test('colorValue returns correct colors', () {
      // High confidence - green
      expect(
        JobConfidence(score: 0.9, assessment: 'HIGH', reasoning: '').colorValue,
        0xFF3FB950,
      );

      // Medium confidence - yellow
      expect(
        JobConfidence(score: 0.6, assessment: 'MEDIUM', reasoning: '').colorValue,
        0xFFD29922,
      );

      // Low confidence - red
      expect(
        JobConfidence(score: 0.3, assessment: 'LOW', reasoning: '').colorValue,
        0xFFF85149,
      );
    });

    test('displayLabel returns correct labels', () {
      expect(
        JobConfidence(score: 0.9, assessment: 'HIGH', reasoning: '').displayLabel,
        'High Confidence',
      );
      expect(
        JobConfidence(score: 0.6, assessment: 'MEDIUM', reasoning: '').displayLabel,
        'Medium Confidence',
      );
      expect(
        JobConfidence(score: 0.3, assessment: 'LOW', reasoning: '').displayLabel,
        'Low Confidence',
      );
    });

    test('percentageString formats correctly', () {
      expect(
        JobConfidence(score: 0.85, assessment: 'HIGH', reasoning: '').percentageString,
        '85%',
      );
      expect(
        JobConfidence(score: 0.333, assessment: 'LOW', reasoning: '').percentageString,
        '33%',
      );
    });
  });

  group('Job with confidence', () {
    test('parses confidence from JSON', () {
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
        'confidence': {
          'score': 0.85,
          'assessment': 'HIGH',
          'reasoning': 'Standard implementation',
          'risks': 'None',
        },
      };

      final job = Job.fromJson('test-job-id', json);

      expect(job.confidence, isNotNull);
      expect(job.confidence!.score, 0.85);
      expect(job.confidence!.assessment, 'HIGH');
    });

    test('handles missing confidence field', () {
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

      expect(job.confidence, isNull);
    });

    test('handles null confidence field', () {
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
        'confidence': null,
      };

      final job = Job.fromJson('test-job-id', json);

      expect(job.confidence, isNull);
    });
  });
}
