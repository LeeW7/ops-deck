# Server-Side Hidden Issues Implementation

## Overview

Add server-side storage for hidden issues so that hiding an issue on one device syncs to all devices.

## API Endpoints Required

### 1. GET /api/hidden-issues

Fetch all hidden issues.

**Response (200 OK):**
```json
[
  {
    "issue_key": "owner/repo#123",
    "repo": "owner/repo",
    "issue_num": 123,
    "issue_title": "Fix the bug",
    "hidden_at": 1706300000000,
    "reason": "user"
  }
]
```

**Notes:**
- `hidden_at` is Unix timestamp in milliseconds
- `reason` is either `"user"` (manually hidden) or `"closed"` (hidden after closing)
- Return empty array `[]` if no hidden issues

### 2. POST /api/hidden-issues

Add a hidden issue.

**Request Body:**
```json
{
  "issue_key": "owner/repo#123",
  "repo": "owner/repo",
  "issue_num": 123,
  "issue_title": "Fix the bug",
  "reason": "user"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "issue_key": "owner/repo#123"
}
```

**Notes:**
- If issue already hidden, update it (upsert behavior)
- `reason` defaults to `"user"` if not provided

### 3. DELETE /api/hidden-issues/:issueKey

Remove a hidden issue (restore to board).

**URL Parameter:**
- `issueKey`: URL-encoded issue key (e.g., `owner%2Frepo%23123`)

**Response (200 OK or 204 No Content):**
```json
{
  "success": true
}
```

**Notes:**
- Return 200/204 even if issue wasn't hidden (idempotent)
- The client URL-encodes the issue key since it contains `/` and `#`

## Storage

SQLite table (consistent with other claude-ops data storage):

```sql
CREATE TABLE IF NOT EXISTS hidden_issues (
  issue_key TEXT PRIMARY KEY,
  repo TEXT NOT NULL,
  issue_num INTEGER NOT NULL,
  issue_title TEXT NOT NULL,
  hidden_at INTEGER NOT NULL,  -- Unix timestamp ms
  reason TEXT DEFAULT 'user'
);
```

Use `INSERT OR REPLACE` for upsert behavior on POST.

## Implementation Prompt for Claude

Use this prompt in claude-ops to implement:

---

**Prompt:**

Implement hidden issues sync endpoints for the ops-deck mobile app. This allows hiding issues from the Kanban board to persist across all devices.

Add these 3 endpoints:

1. `GET /api/hidden-issues` - Return array of all hidden issues
2. `POST /api/hidden-issues` - Add/update a hidden issue (upsert)
3. `DELETE /api/hidden-issues/:issueKey` - Remove a hidden issue

Data model:
```
issue_key: String (e.g., "owner/repo#123") - PRIMARY KEY
repo: String
issue_num: Int
issue_title: String
hidden_at: Int (Unix timestamp milliseconds)
reason: String ("user" or "closed")
```

Storage: Use a simple JSON file at `data/hidden_issues.json` (or SQLite if you prefer).

The client sends URL-encoded issue keys for DELETE since they contain `/` and `#`.

Keep it simple - no authentication needed (single-user system).

---

## Client Behavior

The ops-deck app will:

1. **On startup**: Fetch hidden issues from server, merge with local cache
2. **When hiding**: Update local cache immediately, then fire-and-forget POST to server
3. **When unhiding**: Update local cache immediately, then fire-and-forget DELETE to server
4. **If server unavailable**: Fall back to local-only behavior (graceful degradation)

The client handles 404 gracefully (endpoint not implemented yet), so you can deploy the server changes independently.
