---
description: Collect and calculate AI productivity metrics for retrospectives
---

# AI Statistics Skill

Collect and calculate AI productivity metrics.

## Metric Collection

```bash
# Get file counts
git diff --name-only HEAD~1 | wc -l           # Files changed
git diff --name-status HEAD~1 | grep "^A" | wc -l  # Files added

# Get line counts
git diff --stat HEAD~1 | tail -1  # Shows insertions/deletions
```

### Language-Specific Test File Detection

| Language | Test File Pattern |
|----------|------------------|
| Java | `*Test.java`, `*Tests.java` |
| TypeScript | `*.test.ts`, `*.spec.ts` |
| Python | `test_*.py`, `*_test.py` |
| Go | `*_test.go` |
| Ruby | `*_spec.rb`, `*_test.rb` |

### Language-Specific Test Case Counting

| Language | Count Pattern |
|----------|---------------|
| Java | `@Test` annotations |
| TypeScript | `it(` or `test(` calls |
| Python | `def test_` methods |
| Go | `func Test` functions |
| Ruby | `it ` or `specify ` blocks |

### Auto-Detect Language

```bash
# Detect primary language from changed files
git diff --name-only HEAD~1 | head -20

# Then use corresponding patterns above
```

## Time Estimation Rates

### Java Patterns (Default)
| Category | Lines | Rate (LOC/hr) |
|----------|-------|---------------|
| Service Logic | N | 10 |
| Test Code | N | 20 |
| TOs/DTOs | N | 40 |
| Config/Boilerplate | N | 50 |

### TypeScript/JavaScript Patterns
| Category | Lines | Rate (LOC/hr) |
|----------|-------|---------------|
| Business Logic | N | 12 |
| React Components | N | 15 |
| Test Code | N | 25 |
| Types/Interfaces | N | 50 |

### Python Patterns
| Category | Lines | Rate (LOC/hr) |
|----------|-------|---------------|
| Business Logic | N | 12 |
| Test Code | N | 25 |
| Data Classes | N | 40 |

## Time Calculation

```
Estimated Hours = Σ (Lines per Category / Rate per Category)
```

Conservative estimate assumes:
- No copy-paste from existing code
- Fresh implementation
- Includes debugging time
- Includes code review time

## Update Cumulative Stats

After each `/ship`, update `.claude/retrospectives/cumulative-stats.json`:

```json
{
  "totalIssues": 0,
  "totalLinesAdded": 0,
  "totalLinesRemoved": 0,
  "totalTestsAdded": 0,
  "totalEstimatedHours": 0,
  "totalActualHours": 0,
  "averageTimeSavingsPercent": 0,
  "lastUpdated": "ISO-DATE"
}
```

## When to Use This Skill

- `/ship` - Collect metrics before creating PR
- `/retrospective` - Analyze metrics for learnings
- Quarterly reviews - Aggregate statistics
