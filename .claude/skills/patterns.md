---
description: Actionable development patterns and learnings from retrospectives
---

# Development Patterns

> Actionable learnings graduated from retrospectives. Reference this before planning and implementing features.

## How to Use This File

| Phase | Action |
|-------|--------|
| `/plan` | Check domain-relevant patterns before designing |
| `/implement` | Review pitfalls in relevant domains before coding |
| `/retrospective` | Graduate new patterns here after validation |

---

## Architecture

- **[Service Layer] Use three-layer pattern** - Split services into *SyncService (entry point), *OrchestrationService (workflow), *DataRetrievalService (external data)
  - *Source: CLAUDE.md architectural decisions*

## Build & Tooling

- **[MapStruct] Annotation processor order matters** - pom.xml must list: mapstruct-processor → lombok → lombok-mapstruct-binding. Wrong order causes silent mapper generation failures
  - *Source: CLAUDE.md troubleshooting*

- **[Coverage] JaCoCo excludes are predefined** - Config, mapper, dao, domain, to, repository, exception classes are excluded from 99% coverage requirement
  - *Source: CLAUDE.md troubleshooting*

## Testing

- **[Unit Tests] Mock external dependencies** - Service tests use Mockito for all dependencies; never hit real external systems in unit tests
  - *Source: CLAUDE.md testing patterns*

## CRM Integration

- **[Dynamics] Use FetchXML for queries** - Not SQL. Use DynamicsQuery builder for type-safe query generation
  - *Source: CLAUDE.md architectural decisions*

- **[Dynamics] Use Javers for delta detection** - Only update changed fields, not the entire entity
  - *Source: CLAUDE.md architectural decisions*

- **[Dynamics] Custom entity prefix** - All custom entities use `eig_` prefix (e.g., `eig_policyterm`, `eig_claim`)
  - *Source: CLAUDE.md architectural decisions*

---

## Graduation Criteria

A learning graduates from retrospective to pattern when:
1. **Reusable** - Applies to future features, not one-off
2. **Actionable** - Clear do/don't guidance
3. **Validated** - Worked in practice

---

*Last updated: 2026-01-24*
