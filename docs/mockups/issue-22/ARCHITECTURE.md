# Architecture: Pull to Refresh on Home Page

## Overview

Add pull-to-refresh functionality to the Kanban board home screen using Flutter's built-in `RefreshIndicator` widget. This is a client-only feature that triggers a manual data refresh via the existing `fetchJobs()` method in `IssueBoardProvider`.

## Technical Approach

### Widget Integration

The `RefreshIndicator` widget will wrap the scrollable content in `KanbanBoardScreen`:

```dart
RefreshIndicator(
  onRefresh: () => provider.fetchJobs(),
  child: // existing board content
)
```

### Mobile vs Desktop Considerations

| Platform | Gesture Support | Implementation |
|----------|-----------------|----------------|
| Mobile | Native pull-to-refresh | `RefreshIndicator` wrapping `PageView` |
| Desktop | Mouse scroll at top | Same `RefreshIndicator` (works with mouse) |

### Key Implementation Details

1. **Mobile Board** (`_buildMobileBoard`):
   - Wrap the `Column` containing the board content with `RefreshIndicator`
   - Ensure the inner content is scrollable by using `SingleChildScrollView` or similar
   - The `PageView` itself is horizontally scrollable, so we need a vertical scroll wrapper for the pull gesture

2. **Desktop Board** (`_buildDesktopBoard`):
   - Wrap the entire board content with `RefreshIndicator`
   - Use `SingleChildScrollView` with `AlwaysScrollableScrollPhysics` to enable pull gesture even when content fits

3. **Async Refresh**:
   - The `onRefresh` callback returns a `Future<void>`
   - `fetchJobs()` already returns `Future<void>` and handles loading state internally
   - The `RefreshIndicator` will show its spinner until the Future completes

## File Changes

### Modified Files

| File | Change |
|------|--------|
| `lib/screens/kanban_board_screen.dart` | Add `RefreshIndicator` wrapper in both `_buildMobileBoard` and `_buildDesktopBoard` |

### No New Files Required

This is a minimal implementation using existing Flutter widgets.

## Data Flow

```
User Pull Gesture
       ↓
RefreshIndicator.onRefresh()
       ↓
IssueBoardProvider.fetchJobs()
       ↓
ApiService.fetchStatus()
       ↓
Update _issues map
       ↓
notifyListeners() → UI rebuilds
       ↓
RefreshIndicator.onRefresh() Future completes
       ↓
Spinner dismissed
```

## Implementation Notes

### ScrollPhysics

For the RefreshIndicator to work properly, the child must be scrollable. Options:

1. **AlwaysScrollableScrollPhysics** - Allows scrolling even when content fits, enabling pull-to-refresh in all cases
2. **BouncingScrollPhysics** (iOS default) - Natural bounce effect on iOS
3. **ClampingScrollPhysics** (Android default) - Stops at edges on Android

Recommended: Use `AlwaysScrollableScrollPhysics` to ensure consistent behavior.

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Pull while already loading | `RefreshIndicator` handles this - shows spinner until complete |
| Network error | `fetchJobs()` sets `_error`, UI shows error state |
| Rapid successive pulls | Each pull waits for the previous refresh to complete |
| WebSocket already updating | Pull refresh provides manual override for user confidence |

## Testing Strategy

### Unit Tests
- Verify `fetchJobs()` is called when `onRefresh` triggers
- Verify loading state is properly managed

### Widget Tests
- Verify `RefreshIndicator` is present in widget tree
- Verify pull gesture triggers refresh callback
- Verify spinner appears and disappears appropriately

### Manual Testing
- Test on both iOS and Android simulators
- Test on physical devices for gesture feel
- Verify desktop browser scroll behavior

## Accessibility

The `RefreshIndicator` widget provides built-in accessibility:
- Screen readers announce refresh state
- No additional semantics required

## Performance Considerations

- `fetchJobs()` already handles caching and avoids unnecessary rebuilds
- WebSocket provides real-time updates; pull-to-refresh is supplementary
- No performance impact - uses existing data fetching infrastructure
