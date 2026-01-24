---
description: Project-specific quality checks for build, test, lint, and coverage operations
---

# Quality Gates Skill

Project-specific quality checks. Commands should delegate to this skill for all build/test operations.

## Commands (from CLAUDE.md)

| Gate | Command |
|------|---------|
| Build | `flutter build apk` |
| Test | `flutter test` |
| Lint | `flutter analyze` |
| Coverage | `{{COVERAGE_COMMAND}}` |

## Thresholds

- **Coverage Target**: {{COVERAGE_THRESHOLD}}%
- **Coverage Report**: {{COVERAGE_REPORT_PATH}}

## Execution Order

1. **Build/Compile** - Verify code compiles
2. **Lint** - Check code style (if configured)
3. **Test** - Run test suite
4. **Coverage** - Verify coverage meets threshold

## Failure Handling

| Gate | On Failure |
|------|------------|
| Build | **BLOCK** - Cannot proceed |
| Lint | **WARN** - Note issues, can proceed |
| Test | **BLOCK** - Cannot proceed |
| Coverage | **WARN** - Note if below threshold |

## Running Quality Gates

```bash
# Full quality gate check
flutter build apk && flutter test

# With coverage
{{COVERAGE_COMMAND}}
```

## When to Use This Skill

- `/implement` - After completing implementation
- `/ship` - Before creating commit/PR
- `/gen-tests` - After generating tests
