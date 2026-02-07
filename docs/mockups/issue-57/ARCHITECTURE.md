# Issue #57: Job Stuck Running But It's Complete

## Overview

This bug fix addresses a state synchronization issue where jobs appear to complete (notification received) but the Kanban board still shows the issue as "Running" instead of transitioning to the correct terminal state.

## Root Cause Analysis

### The Problem

The app has a two-tier update strategy for job status:
1. **WebSocket (primary)**: Real-time `jobCompleted`/`jobFailed` events
2. **HTTP polling (fallback)**: `/api/status` every 60 seconds

The bug occurs due to several interacting issues:

### Issue 1: Race Condition Between WebSocket and HTTP Polling

When the WebSocket receives a `jobCompleted` event, the job status is updated immediately. However, if an HTTP poll response arrives shortly after with older data, it can overwrite the fresh WebSocket update.

**Current behavior** (`lib/providers/issue_board_provider.dart:497-514`):
```dart
final jobs = await _apiService.fetchStatus();
final newIssues = _aggregateJobsIntoIssues(jobs);
// ... no timestamp comparison
_issues = newIssues;  // Overwrites everything
```

### Issue 2: Job ID Mismatch in Updates

In `_updateIssueFromEvent`, jobs are matched by `j.issueId == jobData.id`. If there's any ID format mismatch (e.g., different sources using different ID formats), the update creates a new job instead of updating the existing one.

**Result**: The issue now has two jobs - the original "running" job and a new "completed" job. Since `Issue.status` checks if ANY job is running, the issue stays in "Running".

### Issue 3: Issue Status Derivation Logic

`lib/models/issue_model.dart:134-162`:
```dart
IssueStatus get status {
  // Check if any job is running
  if (jobs.any((j) => j.jobStatus == JobStatus.running || j.jobStatus == JobStatus.pending)) {
    return IssueStatus.running;  // This takes priority
  }
  // ...
}
```

If the running job is never updated to completed, the issue remains in "Running" state.

## Data Flow

```
Server Job Completes
        ↓
   WebSocket Event
        ↓
GlobalEventsService._handleMessage()
        ↓
IssueBoardProvider._handleJobEvent()
        ↓
   switch (event.type):
   ├─ jobCompleted: Creates JobEventData with status
   └─ _updateIssueFromEvent(issueKey, completedJob)
        ↓
   Job matching: j.issueId == jobData.id
        ↓
   [PROBLEM] If no match: adds new job, old running job remains
        ↓
   Issue.status derived from ALL jobs
        ↓
   [PROBLEM] Any running job → IssueStatus.running
```

## Solution Design

### Fix 1: Add Timestamp Validation

Track update timestamps and prevent stale data from overwriting fresh updates.

**Changes**:
- Add `lastServerUpdate` field to track when data was last received
- Compare timestamps before applying updates from HTTP polls
- WebSocket events always override since they're real-time

### Fix 2: Improve Job Matching

Ensure robust job ID matching that handles different ID formats.

**Changes**:
- Normalize job IDs before comparison
- Add fallback matching by (repo, issueNum, command) tuple
- Log mismatches for debugging

### Fix 3: Force Terminal Status from Events

For `jobCompleted` and `jobFailed` events, always set the status to the terminal state.

**Changes**:
```dart
case JobEventType.jobCompleted:
  // Always force 'completed' status - don't rely on event payload
  final completedJob = JobEventData(
    // ...
    status: 'completed',  // Hardcoded, not job.status
  );
```

### Fix 4: Add Debug Logging

Comprehensive logging to diagnose future sync issues.

**Log points**:
- Job event received (type, job ID, status)
- Job matching result (found/not found, matched ID)
- Status update applied (before/after status)
- Timestamp comparison results

### Fix 5: Manual Refresh Capability

Allow users to recover from stuck states by forcing a full refresh.

**UI Changes**:
- Pull-to-refresh on Kanban board (if not already present)
- Clear local cache on refresh
- Re-fetch all jobs from server

## Files to Modify

| File | Changes |
|------|---------|
| `lib/providers/issue_board_provider.dart` | Timestamp validation, improved job matching, debug logging |
| `lib/models/job_model.dart` | Add `lastServerUpdate` field |
| `lib/services/job_cache_service.dart` | Store/retrieve timestamps |
| `lib/models/issue_model.dart` | Optional: Add method to find stale running jobs |

## Implementation Phases

### Phase 1: Core Bug Fix
1. Force terminal status for completion/failure events
2. Improve job ID matching in `_updateIssueFromEvent`
3. Add debug logging

### Phase 2: Race Condition Prevention
1. Add timestamp tracking to Job model
2. Implement timestamp comparison in HTTP poll handler
3. Update cache service to persist timestamps

### Phase 3: User Recovery (Optional)
1. Add force refresh capability
2. Add manual "stuck job" detection and recovery

## Testing Strategy

### Unit Tests
- Test `_updateIssueFromEvent` with matching job ID
- Test `_updateIssueFromEvent` with mismatched job ID
- Test `Issue.status` derivation with various job states

### Integration Tests
- Simulate WebSocket completion event → verify issue moves to Done
- Simulate HTTP poll with stale data → verify it doesn't overwrite
- Simulate ID mismatch scenario → verify job is still updated

### Manual Testing
1. Run a job and verify it completes correctly
2. Kill the WebSocket mid-job and verify HTTP poll catches completion
3. Verify no duplicate jobs appear in issue

## Acceptance Criteria

- [ ] Given a job completes via WebSocket, When the jobCompleted event is received, Then the issue status changes to Done
- [ ] Given a job is completed, When HTTP poll returns stale "running" data, Then the completed status is preserved
- [ ] Given a job ID format differs between sources, When matching jobs for update, Then the correct job is still updated
- [ ] Given a user sees a stuck issue, When they pull to refresh, Then the correct status is displayed

## TDD Template

`data-management` - This is primarily a state synchronization bug involving data flow between WebSocket, HTTP, and local cache.
