# Issue #55: Screenshot Add/Remove Clears Title and Description

## Problem Overview

When a user types text into the Title or Description fields on the Create Issue screen, then adds or removes a screenshot, the typed text is lost. This is a state synchronization bug between the local `TextEditingController`s and the `IssueProvider` state.

## Root Cause Analysis

### Current Flow (Broken)

1. User types in Title/Description fields
2. Text is stored only in local `TextEditingController`s (no `onChanged` handler syncs to provider)
3. User taps to add/remove a screenshot
4. `addScreenshot()` or `removeScreenshot()` calls `notifyListeners()`
5. `Consumer<IssueProvider>` rebuilds
6. `_syncControllers()` listener is triggered
7. `_syncControllers()` syncs controller text with provider's `title`/`body` values
8. Since provider values are empty/old, user's typed text is overwritten

### Why onChanged Was Removed

The commit history suggests `onChanged` handlers were removed because they caused "focus issues due to Consumer rebuild." When `onChanged` calls `setTitle()` or `setBody()`, which calls `notifyListeners()`, the Consumer rebuilds, which can interfere with text input focus.

## Solution Design

### Approach: Selective Sync (Recommended)

Modify `_syncControllers()` to only sync from provider to controllers when the provider values are newer/different AND the change originated from the provider (e.g., AI enhancement), not from a screenshot operation.

The key insight is that `_syncControllers()` should only update controllers when:
1. The provider's title/body was explicitly updated by an external source (AI enhancement)
2. NOT when the provider simply called `notifyListeners()` for an unrelated reason (screenshot operations)

### Implementation

**Option A: Track the source of changes**

Add a flag to indicate when title/body were externally modified:
- Set flag when AI enhancement completes
- Clear flag after sync is performed
- Only sync when flag is set

**Option B: Compare controller text before syncing**

Only sync if the controller is empty and provider has content (initial load case), or if provider text is longer/different due to AI enhancement.

**Option C: Use ValueNotifier for title/body specifically (Over-engineering)**

This would separate title/body state from the main provider, avoiding the notification cascade.

### Recommended: Option A with Simplification

Add a boolean `_titleBodyModifiedByAI` flag that is set to `true` when `enhanceWithAI()` successfully updates title/body, and `false` otherwise. The `_syncControllers()` method only syncs when this flag is `true`, then resets it.

## Files to Modify

### `lib/providers/job_provider.dart`

In `IssueProvider` class:

1. Add a private flag:
   ```dart
   bool _titleBodyModifiedByAI = false;
   bool get titleBodyModifiedByAI => _titleBodyModifiedByAI;
   ```

2. In `enhanceWithAI()`, after updating title/body:
   ```dart
   _title = enhanced['title'] ?? _title;
   _body = enhanced['body'] ?? '';
   _titleBodyModifiedByAI = true;  // <-- Add this
   _isEnhancing = false;
   notifyListeners();
   ```

3. Add method to clear the flag:
   ```dart
   void clearTitleBodyModifiedFlag() {
     _titleBodyModifiedByAI = false;
   }
   ```

4. In `setTitle()` and `setBody()`, do NOT call `notifyListeners()` (remove it):
   ```dart
   void setTitle(String title) {
     _title = title;
     _successMessage = null;
     // Don't call notifyListeners() - avoids rebuilds while typing
   }

   void setBody(String body) {
     _body = body;
     _successMessage = null;
     // Don't call notifyListeners() - avoids rebuilds while typing
   }
   ```

### `lib/screens/create_issue_screen.dart`

1. Modify `_syncControllers()` to check the flag:
   ```dart
   void _syncControllers() {
     if (!mounted || _provider == null) return;

     // Only sync from provider to controllers when AI enhancement updated them
     if (_provider!.titleBodyModifiedByAI) {
       _titleController.text = _provider!.title;
       _bodyController.text = _provider!.body;
       _provider!.clearTitleBodyModifiedFlag();
     }
   }
   ```

## Alternative Simpler Approach

Instead of the flag approach, we could simply remove the `_syncControllers()` listener entirely and only set controller text initially and after AI enhancement completes. This would require:

1. Set initial text in `initState` (if editing existing issue - not applicable here)
2. After AI enhancement button is pressed, manually update controllers

This is simpler but changes the architecture pattern more significantly.

## Testing Strategy

### Manual Test Cases

1. **Add Screenshot Without Clearing Text**
   - Open Create Issue screen
   - Type "Test Title" in title field
   - Type "Test Description" in description field
   - Add a screenshot
   - Verify title and description are preserved

2. **Remove Screenshot Without Clearing Text**
   - Same as above but remove the screenshot instead
   - Verify title and description are preserved

3. **AI Enhancement Still Works**
   - Type a title/description
   - Click "Polish with AI"
   - Verify enhanced text appears in both fields

4. **Multiple Screenshot Operations**
   - Type text, add screenshot, type more, add another screenshot
   - Verify all text is preserved

5. **Screenshot Error/Retry**
   - Add a screenshot that fails to upload
   - Retry the upload
   - Verify text is preserved throughout

## Rollback Plan

If issues arise, the change is contained to two files:
- Revert the flag addition in `IssueProvider`
- Restore the original `_syncControllers()` logic

## Implementation Phases

### Phase 1: Core Fix
- [ ] Add `_titleBodyModifiedByAI` flag to `IssueProvider`
- [ ] Set flag in `enhanceWithAI()`
- [ ] Remove `notifyListeners()` from `setTitle()` and `setBody()`
- [ ] Update `_syncControllers()` to check flag

### Phase 2: Testing
- [ ] Manual testing of all scenarios
- [ ] Verify existing functionality works (AI enhancement, form submission)
