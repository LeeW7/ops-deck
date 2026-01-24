# Architecture: Remove Issues from Board (with Close Issue)

## Overview

This feature allows users to manage their Kanban board by either hiding issues locally or closing them on GitHub. Two distinct actions are provided:

1. **Remove from Board** (local-only): Hides the issue from the board without affecting GitHub. Reversible via undo or by triggering a new job.
2. **Close Issue** (GitHub API): Closes the issue on GitHub and removes it from the board. Cannot be undone from the app.

## Data Models

### Hidden Issues Table (SQLite)

```sql
-- New table in JobCacheService (db version 2)
CREATE TABLE hidden_issues (
  issue_key TEXT PRIMARY KEY,  -- Format: "repoSlug-issueNum" (e.g., "ops-deck-12")
  repo TEXT NOT NULL,
  issue_num INTEGER NOT NULL,
  issue_title TEXT NOT NULL,
  hidden_at INTEGER NOT NULL,  -- Unix timestamp
  reason TEXT DEFAULT 'user'   -- 'user' for manual hide, 'closed' for GitHub close
);

CREATE INDEX idx_hidden_repo ON hidden_issues(repo);
```

### TypeScript Interfaces (for reference)

```typescript
interface HiddenIssue {
  issueKey: string;      // "repoSlug-issueNum"
  repo: string;          // "owner/repo"
  issueNum: number;
  issueTitle: string;
  hiddenAt: Date;
  reason: 'user' | 'closed';
}

interface IssueContextAction {
  type: 'view' | 'github' | 'hide' | 'close';
  issue: Issue;
}
```

## API Endpoints

### Existing Endpoints Used

- `GET /api/status` - Returns all jobs (unchanged)
- `POST /jobs/trigger` - Trigger new job (auto-restores hidden issues)

### New Server Endpoint Required

```
POST /issues/{repo}/{issueNum}/close
```

**Request:**
```json
{
  "reason": "completed" | "not_planned" | "duplicate"  // optional, defaults to "completed"
}
```

**Response (200):**
```json
{
  "success": true,
  "issue_state": "closed"
}
```

**Response (404):**
```json
{
  "error": "Issue not found"
}
```

**Response (403):**
```json
{
  "error": "Insufficient permissions to close issue"
}
```

**Implementation:** The server calls `gh issue close {repo}#{issueNum}` via GitHub CLI.

## Flutter Implementation

### Phase 1: Data Layer

#### 1.1 Database Migration (JobCacheService)

```dart
// lib/services/job_cache_service.dart

class JobCacheService {
  static const int _dbVersion = 2;  // Bump from 1 to 2

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE hidden_issues (
          issue_key TEXT PRIMARY KEY,
          repo TEXT NOT NULL,
          issue_num INTEGER NOT NULL,
          issue_title TEXT NOT NULL,
          hidden_at INTEGER NOT NULL,
          reason TEXT DEFAULT 'user'
        )
      ''');
      await db.execute('CREATE INDEX idx_hidden_repo ON hidden_issues(repo)');
    }
  }

  /// Hide an issue from the board
  Future<void> hideIssue({
    required String issueKey,
    required String repo,
    required int issueNum,
    required String issueTitle,
    String reason = 'user',
  }) async {
    final db = await database;
    await db.insert(
      'hidden_issues',
      {
        'issue_key': issueKey,
        'repo': repo,
        'issue_num': issueNum,
        'issue_title': issueTitle,
        'hidden_at': DateTime.now().millisecondsSinceEpoch,
        'reason': reason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Unhide an issue (restore to board)
  Future<void> unhideIssue(String issueKey) async {
    final db = await database;
    await db.delete(
      'hidden_issues',
      where: 'issue_key = ?',
      whereArgs: [issueKey],
    );
  }

  /// Get all hidden issue keys
  Future<Set<String>> getHiddenIssueKeys() async {
    final db = await database;
    final result = await db.query('hidden_issues', columns: ['issue_key']);
    return result.map((r) => r['issue_key'] as String).toSet();
  }

  /// Check if a specific issue is hidden
  Future<bool> isIssueHidden(String issueKey) async {
    final db = await database;
    final result = await db.query(
      'hidden_issues',
      where: 'issue_key = ?',
      whereArgs: [issueKey],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
```

#### 1.2 ApiService Extension

```dart
// lib/services/api_service.dart

/// Close an issue on GitHub
Future<void> closeIssue(String repo, int issueNum, {String reason = 'completed'}) async {
  final response = await _postWithRetry(
    '/issues/$repo/$issueNum/close',
    body: {'reason': reason},
    maxRetries: 0,  // Don't retry destructive operations
  );

  if (response.statusCode == 200) {
    return;
  } else {
    throw _handleErrorResponse(response, 'close issue');
  }
}
```

#### 1.3 IssueBoardProvider Extension

```dart
// lib/providers/issue_board_provider.dart

class IssueBoardProvider with ChangeNotifier {
  Set<String> _hiddenIssueKeys = {};
  Issue? _recentlyHiddenIssue;  // For undo support
  Timer? _undoTimer;

  /// Get issues filtered by selected repos AND excluding hidden issues
  List<Issue> get filteredIssues {
    var issues = allIssues;
    if (_selectedRepos.isNotEmpty) {
      issues = issues.where((issue) => _selectedRepos.contains(issue.repo)).toList();
    }
    // Filter out hidden issues
    return issues.where((issue) => !_hiddenIssueKeys.contains(issue.key)).toList();
  }

  /// Load hidden issues from cache on initialization
  Future<void> _loadHiddenIssues() async {
    _hiddenIssueKeys = await _cache.getHiddenIssueKeys();
  }

  /// Hide an issue from the board (local only)
  Future<void> hideIssue(Issue issue) async {
    _recentlyHiddenIssue = issue;
    _hiddenIssueKeys.add(issue.key);

    await _cache.hideIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'user',
    );

    notifyListeners();

    // Start undo timer (3 seconds)
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 3), () {
      _recentlyHiddenIssue = null;
    });
  }

  /// Undo hiding the most recently hidden issue
  Future<bool> undoHideIssue() async {
    if (_recentlyHiddenIssue == null) return false;

    final issue = _recentlyHiddenIssue!;
    _hiddenIssueKeys.remove(issue.key);
    await _cache.unhideIssue(issue.key);

    _recentlyHiddenIssue = null;
    _undoTimer?.cancel();

    notifyListeners();
    return true;
  }

  /// Close an issue on GitHub and hide from board
  Future<void> closeIssue(Issue issue) async {
    await _apiService.closeIssue(issue.repo, issue.issueNum);

    // Hide locally after successful close
    _hiddenIssueKeys.add(issue.key);
    await _cache.hideIssue(
      issueKey: issue.key,
      repo: issue.repo,
      issueNum: issue.issueNum,
      issueTitle: issue.title,
      reason: 'closed',
    );

    notifyListeners();
  }

  /// Check if there's a recent hide that can be undone
  bool get canUndo => _recentlyHiddenIssue != null;

  /// Auto-restore hidden issues when new jobs appear
  void _updateIssueFromEvent(String issueKey, JobEventData jobData) {
    // If this issue was hidden but now has new activity, restore it
    if (_hiddenIssueKeys.contains(issueKey)) {
      _hiddenIssueKeys.remove(issueKey);
      _cache.unhideIssue(issueKey);
    }
    // ... existing code
  }
}
```

### Phase 2: UI Components

#### 2.1 Issue Context Menu Widget

```dart
// lib/widgets/kanban/issue_context_menu.dart

class IssueContextMenu extends StatelessWidget {
  final Issue issue;
  final VoidCallback onViewDetails;
  final VoidCallback onOpenInGitHub;
  final VoidCallback onRemoveFromBoard;
  final VoidCallback onCloseIssue;
  final VoidCallback onDismiss;

  const IssueContextMenu({
    super.key,
    required this.issue,
    required this.onViewDetails,
    required this.onOpenInGitHub,
    required this.onRemoveFromBoard,
    required this.onCloseIssue,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: Icons.open_in_new,
              label: 'View Details',
              onTap: onViewDetails,
            ),
            _buildMenuItem(
              icon: Icons.link,
              label: 'Open in GitHub',
              onTap: onOpenInGitHub,
            ),
            const Divider(color: Color(0xFF30363D), height: 1),
            _buildMenuItem(
              icon: Icons.visibility_off_outlined,
              label: 'Remove from Board',
              onTap: onRemoveFromBoard,
            ),
            _buildMenuItem(
              icon: Icons.close,
              label: 'Close Issue',
              onTap: onCloseIssue,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? const Color(0xFFDA3633) : const Color(0xFFE6EDF3);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 2.2 Confirmation Dialogs

```dart
// lib/widgets/dialogs/remove_confirmation_dialog.dart

class RemoveConfirmationDialog extends StatelessWidget {
  final Issue issue;

  const RemoveConfirmationDialog({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      title: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: Color(0xFF8B949E)),
          const SizedBox(width: 8),
          const Text(
            'Remove from Board',
            style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hide this issue from your Kanban board? You can trigger a new job to restore it.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildIssuePreview(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
          ),
          child: const Text('Remove'),
        ),
      ],
    );
  }

  Widget _buildIssuePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  issue.repoSlug,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8B949E),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${issue.issueNum}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF0883E),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE6EDF3),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/widgets/dialogs/close_issue_dialog.dart

class CloseIssueDialog extends StatelessWidget {
  final Issue issue;

  const CloseIssueDialog({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      title: Row(
        children: [
          const Icon(Icons.close, color: Color(0xFFDA3633)),
          const SizedBox(width: 8),
          const Text(
            'Close Issue',
            style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Close this issue on GitHub? The issue will be marked as closed and removed from your board.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildIssuePreview(),
          const SizedBox(height: 12),
          _buildWarningBox(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDA3633),
          ),
          child: const Text('Close Issue'),
        ),
      ],
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDA3633).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDA3633).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFDA3633), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'This action cannot be undone from the app. You can reopen the issue from GitHub.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B949E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Phase 3: Integration

#### 3.1 IssueCard with Long Press

```dart
// lib/widgets/kanban/issue_card.dart (modifications)

class IssueCard extends StatefulWidget {
  final Issue issue;
  final VoidCallback? onTap;
  final Function(Issue)? onContextMenu;  // NEW

  const IssueCard({
    super.key,
    required this.issue,
    this.onTap,
    this.onContextMenu,  // NEW
  });

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  bool _isLongPressActive = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isLongPressActive = true);
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        setState(() => _isLongPressActive = false);
        widget.onContextMenu?.call(widget.issue);
      },
      onSecondaryTap: () {
        // Right-click support for desktop
        widget.onContextMenu?.call(widget.issue);
      },
      child: AnimatedScale(
        scale: _isLongPressActive ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _isLongPressActive ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Material(
            // ... existing build code
          ),
        ),
      ),
    );
  }
}
```

#### 3.2 Toast Notification

```dart
// Show in KanbanBoardScreen after hide action
void _showHideToast(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF3FB950)),
          const SizedBox(width: 8),
          const Text('Issue hidden from board'),
        ],
      ),
      action: SnackBarAction(
        label: 'Undo',
        textColor: const Color(0xFF58A6FF),
        onPressed: () {
          context.read<IssueBoardProvider>().undoHideIssue();
        },
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF161B22),
    ),
  );
}
```

## Security Considerations

1. **GitHub API Permissions**: The close issue endpoint requires the server to have write access to the repository. Users without permission will see an error.

2. **Local Storage Only for Hide**: The "Remove from Board" action is purely local and doesn't affect GitHub. Users cannot accidentally modify issues they don't own.

3. **Confirmation Dialogs**: Both actions require confirmation to prevent accidental removals.

4. **No Undo for Close**: The close action warning clearly states it cannot be undone from the app, setting proper expectations.

## Testing Strategy

### Unit Tests
- `JobCacheService` hidden issues CRUD operations
- `IssueBoardProvider` filtering with hidden issues
- `IssueBoardProvider` undo functionality with timer

### Widget Tests
- `IssueContextMenu` renders all options
- `RemoveConfirmationDialog` cancel/confirm actions
- `CloseIssueDialog` warning display and actions
- `IssueCard` long press gesture recognition

### Integration Tests
- Full flow: Long press → Context menu → Remove → Toast → Undo
- Full flow: Long press → Context menu → Close → Confirmation → Success
- Hidden issues persist across app restarts
- New job restores hidden issue

## File Changes Summary

### New Files
- `lib/widgets/kanban/issue_context_menu.dart`
- `lib/widgets/dialogs/remove_confirmation_dialog.dart`
- `lib/widgets/dialogs/close_issue_dialog.dart`

### Modified Files
- `lib/services/job_cache_service.dart` - Add hidden_issues table and methods
- `lib/services/api_service.dart` - Add closeIssue method
- `lib/providers/issue_board_provider.dart` - Add hide/unhide/close methods and filtering
- `lib/widgets/kanban/issue_card.dart` - Add long press and right-click gestures
- `lib/screens/kanban_board_screen.dart` - Wire up context menu and dialogs

## Implementation Phases

### Phase 1: Data Layer
- [ ] Add `hidden_issues` table to SQLite schema
- [ ] Implement database migration (version 1 → 2)
- [ ] Add `JobCacheService` methods: `hideIssue()`, `unhideIssue()`, `getHiddenIssueKeys()`
- [ ] Add `ApiService.closeIssue()` method
- [ ] Add `IssueBoardProvider` state and methods

### Phase 2: UI Components
- [ ] Create `IssueContextMenu` widget
- [ ] Create `RemoveConfirmationDialog` widget
- [ ] Create `CloseIssueDialog` widget
- [ ] Add long-press gesture to `IssueCard`
- [ ] Implement toast notification with undo action

### Phase 3: Integration
- [ ] Wire up context menu to `KanbanBoardScreen`
- [ ] Connect provider methods to UI actions
- [ ] Add desktop right-click support
- [ ] Implement undo functionality with timer

### Phase 4: Polish
- [ ] Add haptic feedback on long-press
- [ ] Implement removal animation (fade out)
- [ ] Update empty column states
- [ ] Test edge cases
