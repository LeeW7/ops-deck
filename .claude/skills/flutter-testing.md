---
description: Flutter testing patterns for models, services, and widgets in Ops Deck
---

# Flutter Testing

## When to Use
- Writing unit tests for models
- Testing service methods
- Testing provider state changes
- Writing widget tests

## Patterns

### Model Test Structure
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/models/my_model.dart';

void main() {
  group('MyModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': '123',
        'name': 'Test',
        'status': 'active',
      };

      final model = MyModel.fromJson(json);

      expect(model.id, '123');
      expect(model.name, 'Test');
      expect(model.status, 'active');
    });

    test('handles missing optional fields with defaults', () {
      final json = {'id': '123'};
      final model = MyModel.fromJson(json);

      expect(model.name, '');
      expect(model.status, 'unknown');
    });

    group('computed properties', () {
      test('isActive returns true for active status', () {
        final model = _createModel('active');
        expect(model.isActive, true);
      });

      test('isActive returns false for inactive status', () {
        final model = _createModel('inactive');
        expect(model.isActive, false);
      });
    });
  });
}

// Helper function
MyModel _createModel(String status) {
  return MyModel.fromJson({
    'id': 'test',
    'status': status,
  });
}
```

### Testing Enum Mapping
```dart
group('statusEnum', () {
  test('maps active status', () {
    final model = _createModel('active');
    expect(model.statusEnum, Status.active);
  });

  test('maps unknown for invalid value', () {
    final model = _createModel('invalid');
    expect(model.statusEnum, Status.unknown);
  });

  test('is case insensitive', () {
    final model = _createModel('ACTIVE');
    expect(model.statusEnum, Status.active);
  });
});
```

### Testing Response Parsing
```dart
group('parseResponse', () {
  test('parses array response', () {
    final json = [
      {'id': '1', 'name': 'Item 1'},
      {'id': '2', 'name': 'Item 2'},
    ];

    final items = MyModel.parseResponse(json);

    expect(items.length, 2);
    expect(items['1']?.name, 'Item 1');
  });

  test('parses object response', () {
    final json = {
      '1': {'name': 'Item 1'},
      '2': {'name': 'Item 2'},
    };

    final items = MyModel.parseResponse(json);
    expect(items.length, 2);
  });

  test('handles empty input', () {
    expect(MyModel.parseResponse([]).isEmpty, true);
    expect(MyModel.parseResponse(<String, dynamic>{}).isEmpty, true);
  });
});
```

### Testing Type Coercion
```dart
test('parses numeric as int or double', () {
  final jsonInt = {'value': 100};
  final jsonDouble = {'value': 100.5};

  expect(MyModel.fromJson(jsonInt).value, 100);
  expect(MyModel.fromJson(jsonDouble).value, 100); // Truncated
});
```

### Testing Calculations
```dart
test('calculates duration correctly', () {
  final json = {
    'start_time': 1000,
    'end_time': 1060, // 60 seconds later
  };

  final model = MyModel.fromJson(json);

  expect(model.duration, Duration(seconds: 60));
  expect(model.formattedDuration, '1m 0s');
});

test('duration is null when not completed', () {
  final json = {'start_time': 1000};
  final model = MyModel.fromJson(json);

  expect(model.duration, isNull);
});
```

## Best Practices

1. **Use `group()` for organization** - Related tests in named groups
2. **Create helper functions** - `_createModel()` for consistent test data
3. **Test edge cases** - Null, empty, invalid values
4. **Test case insensitivity** - Enum/status mapping
5. **Use descriptive test names** - `verb + scenario + expected result`

## Common Tasks

### Adding Tests for New Model
1. Create `test/models/<model_name>_test.dart`
2. Add `group()` for the model
3. Test JSON parsing (required and optional fields)
4. Test computed properties
5. Test enum mapping if applicable

### Test Data Conventions
```dart
// Use fixed, realistic values
final testJson = {
  'id': 'test-123',
  'status': 'running',
  'start_time': 1705900000, // Fixed timestamp
  'name': 'Test Item',
};

// Use helpers for variations
MyModel _createWithStatus(String status) => MyModel.fromJson({
  'id': 'test',
  'status': status,
  'start_time': 1705900000,
});
```

### Running Tests
```bash
# All tests
flutter test

# Single file
flutter test test/models/my_model_test.dart

# With coverage
flutter test --coverage

# Verbose output
flutter test -v
```
