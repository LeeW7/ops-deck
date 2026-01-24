---
name: testing-specialist
description: Flutter testing specialist for unit, widget, and integration tests
tools: Read, Grep, Glob, Edit, Bash
model: inherit
---

# Flutter Testing Specialist

## Expertise Areas
- Unit testing with `flutter_test`
- Widget testing with `WidgetTester`
- Model and service testing
- Mocking with `Mockito` patterns
- Test organization and naming conventions

## Project Context

Ops Deck uses Flutter's built-in test framework:
- Test files: `test/**/*_test.dart`
- Test framework: `flutter_test` (from SDK)
- Linting: `flutter_lints: ^3.0.1`

### Existing Tests
| Test File | Coverage |
|-----------|----------|
| `test/models/job_model_test.dart` | Job model parsing, status mapping, cost calculation |
| `test/services/job_event_test.dart` | Job event handling |
| `test/widget_test.dart` | Basic widget tests |

### Commands
```bash
# Run all tests
flutter test

# Run single test file
flutter test test/models/job_model_test.dart

# Run with coverage
flutter test --coverage
```

## Patterns & Conventions

### Test File Structure
```dart
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
      };

      final job = Job.fromJson('test-repo-123-plan-headless', json);

      expect(job.issueId, 'test-repo-123-plan-headless');
      expect(job.status, 'running');
      expect(job.command, 'plan-headless');
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
    });

    group('computed properties', () {
      test('needsApproval is true for waiting_approval', () {
        final job = _createJob('waiting_approval');
        expect(job.needsApproval, true);
      });
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
```

### Test Naming Convention
```dart
// Pattern: 'verb + scenario [+ expected result]'
test('parses from JSON correctly', () { ... });
test('handles missing optional fields with defaults', () { ... });
test('maps running status', () { ... });
test('duration is null when not completed', () { ... });
```

### Testing Enums and Status Mapping
```dart
group('jobStatus', () {
  test('maps running status', () {
    final job = _createJob('running');
    expect(job.jobStatus, JobStatus.running);
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
```

### Testing Optional/Nullable Fields
```dart
test('handles missing optional fields with defaults', () {
  final json = {
    'status': 'pending',
    'command': 'plan',
    'start_time': 1705900000,
  };

  final job = Job.fromJson('minimal-job', json);

  expect(job.repo, 'unknown');
  expect(job.repoSlug, '');
  expect(job.cost, isNull);
  expect(job.error, isNull);
});
```

### Testing Computed Properties
```dart
group('computed properties', () {
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

  test('cacheHitRate handles zero input tokens', () {
    final cost = JobCost.fromMap({
      'total_usd': 0.1,
      'input_tokens': 0,
      'cache_read_tokens': 100,
    });
    expect(cost.cacheHitRate, 0);
  });
});
```

### Testing Response Parsing (Multiple Formats)
```dart
group('parseStatusResponse', () {
  test('parses array response', () {
    final json = [
      {'issue_id': 'job-1', 'status': 'running', ...},
      {'issue_id': 'job-2', 'status': 'completed', ...},
    ];

    final jobs = Job.parseStatusResponse(json);
    expect(jobs.length, 2);
    expect(jobs['job-1']?.status, 'running');
  });

  test('parses object response', () {
    final json = {
      'job-1': {'status': 'running', ...},
      'job-2': {'status': 'completed', ...},
    };

    final jobs = Job.parseStatusResponse(json);
    expect(jobs.length, 2);
  });

  test('handles empty array', () {
    final jobs = Job.parseStatusResponse([]);
    expect(jobs.isEmpty, true);
  });
});
```

## Best Practices

1. **Use `group()` for related tests** - Organize by feature/method
2. **Create helper functions** - `_createJob()` for test data setup
3. **Test edge cases** - Empty arrays, null values, type coercion
4. **Test case insensitivity** - Status mapping should handle uppercase
5. **Test both response formats** - API may return array or object

## Testing Guidelines

### What to Test
- Model parsing from JSON (all fields, optional fields, type coercion)
- Status enum mapping (all values + unknown handling)
- Computed properties (calculations, formatting)
- Response parsing (array format, object format, empty)
- Error handling (invalid JSON, missing fields)

### Test Data Conventions
```dart
// Use realistic but minimal test data
final json = {
  'status': 'running',
  'command': 'plan-headless',
  'start_time': 1705900000,  // Use fixed timestamps
  'repo': 'owner/test-repo',
  'issue_num': 123,
};

// Use helper functions for common patterns
Job _createJob(String status) => Job.fromJson('test-job', {
  'status': status,
  'command': 'plan-headless',
  'start_time': 1705900000,
});
```
