# Architecture: Issue #59 - Job Stuck Running After Completion

## Overview

This issue reports that Issue #58 is still showing as "Running" even though all jobs are complete. Despite the fix in PR #58 (which addressed WebSocket/HTTP polling race conditions), the problem persists.

## Root Cause Analysis

After reviewing the codebase, I've identified potential remaining issues:

### 1. SQLite Cache Not Updated on WebSocket Terminal Events

**Location:** `issue_board_provider.dart:266-290`

When a `jobCompleted` or `jobFailed` WebSocket event is received:
```dart
case JobEventType.jobCompleted:
  final completedJob = JobEventData(...status: 'completed');
  _updateIssueFromEvent(issueKey, completedJob);
  _cache.updateJobStatus(completedJob.id, 'completed'); // Line 288
```

**Problem:** The SQLite cache is updated, but on app restart, the cached jobs are loaded BEFORE WebSocket reconnects. If the last HTTP poll captured stale "running" status, the cache has stale data.

### 2. Cache Load Occurs Before Fresh Data

**Location:** `issue_board_provider.dart:117-135`

```dart
Future<void> initialize() async {
  await _loadFromCache();           // 1. Load stale cache first
  await _loadHiddenIssues();        // 2. Load hidden issues
  if (_isConfigured) {
    await fetchRepos();
    _connectWebSocket();            // 3. Connect WebSocket (async, may not complete before UI renders)
    fetchJobs();                    // 4. HTTP fetch (not awaited!)
  }
}
```

**Problem:** The cache is loaded immediately, but `fetchJobs()` is not awaited. If the UI renders before fresh data arrives, it shows stale "running" status.

### 3. HTTP Poll May Return Stale Data From Server

The server's `/api/status` endpoint may be caching or have eventual consistency delays. The terminal status preservation logic in `_aggregateJobsIntoIssues` (lines 584-680) only works if we already have the terminal job in memory from a previous WebSocket event.

### 4. Job ID Mismatch Between Cache and New Events

**Location:** `issue_board_provider.dart:355-367`

The `_jobIdsMatch` function normalizes IDs but doesn't handle all edge cases. If a cached job has a different ID format than the WebSocket event, the terminal status won't be matched.

## Proposed Solution

### Phase 1: Force Terminal Status Refresh on App Launch

On app start, after loading from cache, check for jobs that are "running" for too long (e.g., > 1 hour) and mark them as stale. Then force a fresh HTTP fetch.

### Phase 2: Add "Stuck Job" Detection

Add a heuristic to detect jobs that have been running for an abnormally long time and should be considered potentially stuck:

```dart
extension on Job {
  bool get isPotentiallyStuck {
    if (jobStatus != JobStatus.running && jobStatus != JobStatus.pending) {
      return false;
    }
    // If running for more than 2 hours, consider potentially stuck
    final runningDuration = DateTime.now().difference(startDateTime);
    return runningDuration.inHours >= 2;
  }
}
```

### Phase 3: Add Manual Refresh with Cache Clear

Allow users to force a complete refresh by long-pressing the refresh button, which:
1. Clears the SQLite cache
2. Reconnects WebSocket
3. Fetches fresh data from server

### Phase 4: Add Debug Overlay for Job State

In debug mode, allow users to tap a stuck job to see:
- Cache status vs server status
- Last WebSocket event received
- Job ID format comparison

## Data Flow Diagram

```
App Launch
    │
    ▼
Load SQLite Cache ──► UI Renders (may show stale "running")
    │
    ▼
Connect WebSocket ──► Receive jobCompleted event ──► Update in-memory + cache
    │
    ▼
HTTP Poll (backup) ──► _aggregateJobsIntoIssues ──► Preserve terminal if already known
```

## Files to Modify

1. **lib/models/job_model.dart**
   - Add `isPotentiallyStuck` computed property
   - Add `runningDuration` computed property

2. **lib/providers/issue_board_provider.dart**
   - Add stuck job detection on cache load
   - Add force refresh method that clears cache
   - Improve terminal status handling for cached jobs

3. **lib/services/job_cache_service.dart**
   - Add method to mark stale "running" jobs as "unknown"
   - Add method to clear specific job from cache

4. **lib/screens/kanban_board_screen.dart** (optional)
   - Add long-press gesture for force refresh

## Acceptance Criteria

1. Given a job completes while the app is closed, When the app is reopened, Then the job should show as "Done" (not "Running")

2. Given a job has been "running" for over 2 hours, When the user views the board, Then the job should be flagged as potentially stuck with a visual indicator

3. Given a user suspects stale data, When they long-press refresh, Then all cached data is cleared and fresh data is fetched

4. Given a WebSocket jobCompleted event is received, When the app is later restarted, Then the cache should correctly show "completed" status

## Testing Strategy

1. **Unit Tests:**
   - Test `isPotentiallyStuck` property
   - Test cache staleness detection logic
   - Test terminal status preservation across cache/HTTP/WebSocket sources

2. **Integration Tests:**
   - Simulate app restart with stale cache
   - Simulate WebSocket event followed by HTTP poll with stale data
   - Simulate cache clear and refresh

3. **Manual Testing:**
   - Let a real job complete while app is backgrounded
   - Kill and restart app
   - Verify correct status shown
