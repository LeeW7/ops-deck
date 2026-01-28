# Issue #29: Pull-to-Refresh for Kanban Board

## Overview

Add pull-to-refresh functionality to the main home page Kanban board (`KanbanBoardScreen`). This allows users to manually trigger a data refresh by pulling down on the board.

## Current Architecture

The `KanbanBoardScreen` has two layouts:
1. **Mobile** (`<600px`): Uses `PageView.builder` with swipeable columns
2. **Desktop** (`>=600px`): Uses horizontal `Row` with fixed columns

Data is managed by `IssueBoardProvider` which:
- Fetches data via `fetchJobs()` method
- Uses WebSocket for real-time updates
- Has 60-second backup polling

## Implementation Approach

### Challenge: RefreshIndicator with PageView

`RefreshIndicator` requires a scrollable child with `AlwaysScrollableScrollPhysics`. However, `PageView` scrolls horizontally, not vertically.

**Solution**: Wrap the entire mobile board content in a `RefreshIndicator` containing a `SingleChildScrollView` (or use a `CustomScrollView` with `SliverFillRemaining`).

For the mobile layout, wrap the `PageView` inside a vertically-scrollable container that triggers the `RefreshIndicator`:

```dart
RefreshIndicator(
  onRefresh: () => provider.fetchJobs(),
  child: CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          children: [
            // Done column header
            Padding(...),
            // PageView (expand to fill)
            Expanded(child: PageView.builder(...)),
            // Page indicator
            _buildPageIndicator(),
          ],
        ),
      ),
    ],
  ),
)
```

For the desktop layout, a similar approach wrapping the `Row` of columns.

### Alternative Approach (Simpler)

Wrap the entire `_buildBoard` output in a `Stack` with a `RefreshIndicator` overlay that uses a hidden `ListView`:

```dart
RefreshIndicator(
  onRefresh: () => provider.fetchJobs(),
  child: Stack(
    children: [
      // Hidden scrollable for refresh gesture
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight + 1)],
      ),
      // Actual content
      _buildMobileBoard(context, provider),
    ],
  ),
)
```

### Recommended Approach

Use the `CustomScrollView` with `SliverFillRemaining` approach as it's cleaner and doesn't require a hidden widget hack.

## Files to Modify

| File | Changes |
|------|---------|
| `lib/screens/kanban_board_screen.dart` | Wrap mobile and desktop board layouts with `RefreshIndicator` |

## Implementation Details

### Mobile Layout Changes (`_buildMobileBoard`)

```dart
Widget _buildMobileBoard(BuildContext context, IssueBoardProvider provider) {
  return RefreshIndicator(
    onRefresh: () => provider.fetchJobs(),
    color: Theme.of(context).colorScheme.primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              // Done column header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: DoneColumnHeader(
                  count: provider.doneIssues.length,
                  onTap: () => _openSearch(context, initialStatus: IssueStatus.done),
                ),
              ),
              // Swipeable columns
              Expanded(
                child: PageView.builder(...),
              ),
              // Page indicator
              _buildPageIndicator(),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Desktop Layout Changes (`_buildDesktopBoard`)

Similar wrapping with `RefreshIndicator` and `CustomScrollView`.

## Styling

Follow existing patterns from `DashboardScreen` and `QuickTasksScreen`:

```dart
RefreshIndicator(
  onRefresh: () => provider.fetchJobs(),
  color: Theme.of(context).colorScheme.primary,
  // or specific color like const Color(0xFF00FF41) for accent
  child: ...
)
```

## Testing Strategy

### Manual Testing
1. Pull down on the Kanban board (mobile layout)
2. Verify refresh indicator appears
3. Verify data refreshes when released
4. Verify indicator dismisses after refresh completes
5. Test desktop layout similarly

### Unit Tests
- Test that `IssueBoardProvider.fetchJobs()` is called on refresh
- Mock the provider and verify refresh behavior

## Edge Cases

1. **Empty board**: RefreshIndicator should still work
2. **Error state**: Should still allow refresh
3. **Loading state**: Should show loading indicator
4. **Rapid refresh**: Should debounce multiple rapid refreshes (handled by provider)

## Security Considerations

None - this is a UI-only feature that uses existing data fetching methods.

## Performance Considerations

- `fetchJobs()` is already optimized and debounced
- RefreshIndicator provides visual feedback during the async operation
- No additional network calls beyond what already exists
