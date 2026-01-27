# Architecture: Pull to Refresh for Kanban Board

## Overview

Add pull-to-refresh functionality to the main Kanban board screen, allowing users to manually trigger a refresh of issue data by pulling down on the screen (mobile) or clicking a refresh button (desktop).

## Technical Approach

Flutter provides a built-in `RefreshIndicator` widget that wraps scrollable content and provides the pull-to-refresh gesture with platform-appropriate visual feedback.

### Implementation Strategy

The current `_buildMobileBoard` uses a `PageView.builder` for horizontal swiping between columns. To add pull-to-refresh, we need to wrap the entire scrollable content (including the Done header and PageView) in a `RefreshIndicator`.

Since `RefreshIndicator` requires a vertically scrollable child, we'll wrap the existing Column in a `SingleChildScrollView` with `AlwaysScrollableScrollPhysics` to ensure the pull gesture works even when content doesn't overflow.

## Data Flow

```
User pulls down
    ↓
RefreshIndicator triggers onRefresh callback
    ↓
IssueBoardProvider.fetchJobs() is called
    ↓
API request to /api/status
    ↓
Jobs are aggregated into Issues
    ↓
State updates, UI rebuilds
    ↓
RefreshIndicator completes (spinner hides)
```

## API Endpoints

No new endpoints required. Uses existing:
- `GET /api/status` - Returns all jobs

## Code Changes

### File: `lib/screens/kanban_board_screen.dart`

#### 1. Add refresh method to state class

```dart
Future<void> _handleRefresh() async {
  await context.read<IssueBoardProvider>().fetchJobs();
}
```

#### 2. Modify `_buildMobileBoard` method

Wrap the existing Column in a RefreshIndicator:

```dart
Widget _buildMobileBoard(BuildContext context, IssueBoardProvider provider) {
  return RefreshIndicator(
    onRefresh: _handleRefresh,
    color: Theme.of(context).colorScheme.primary,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top -
                56, // AppBar bottom (filter chips)
        child: Column(
          children: [
            // Done column header (existing code)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DoneColumnHeader(
                count: provider.doneIssues.length,
                onTap: () => _openSearch(context, initialStatus: IssueStatus.done),
              ),
            ),
            // Swipeable columns (existing code)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _columnStatuses.length,
                itemBuilder: (context, index) {
                  // ... existing itemBuilder code
                },
              ),
            ),
            // Page indicator (existing code)
            _buildPageIndicator(),
          ],
        ),
      ),
    ),
  );
}
```

#### 3. Modify `_buildDesktopBoard` method (optional enhancement)

For desktop, add a refresh button in the UI since pull-to-refresh is a mobile gesture:

```dart
Widget _buildDesktopBoard(BuildContext context, IssueBoardProvider provider) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Header row with Done and Refresh button
        Row(
          children: [
            Expanded(
              child: DoneColumnHeader(
                count: provider.doneIssues.length,
                onTap: () => _openSearch(context, initialStatus: IssueStatus.done),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: provider.isLoading ? null : _handleRefresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ... rest of existing desktop board code
      ],
    ),
  );
}
```

## UX Considerations

1. **Visual Feedback**: The `RefreshIndicator` provides a material design spinner that appears when pulling down, giving clear feedback that a refresh is in progress.

2. **Loading State**: The provider's `isLoading` state is used to show a loading indicator and prevent multiple simultaneous refresh requests.

3. **Haptic Feedback**: Flutter's `RefreshIndicator` automatically provides haptic feedback on iOS when the refresh threshold is reached.

4. **Pull Distance**: Default threshold (40 logical pixels of overscroll) is sufficient; no customization needed.

5. **Desktop Fallback**: A manual refresh button is provided for desktop users who cannot perform the pull gesture.

## Testing Strategy

### Unit Tests
- Verify `fetchJobs()` is called when refresh is triggered
- Verify refresh completes when `fetchJobs()` completes

### Widget Tests
```dart
testWidgets('pull to refresh triggers fetchJobs', (tester) async {
  // Build widget
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => mockProvider,
      child: const MaterialApp(home: KanbanBoardScreen()),
    ),
  );

  // Simulate pull to refresh
  await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
  await tester.pumpAndSettle();

  // Verify fetchJobs was called
  verify(mockProvider.fetchJobs()).called(1);
});
```

### Integration Tests
- Manually test on iOS and Android devices
- Verify spinner animation is smooth
- Verify data updates after refresh

## Implementation Phases

### Phase 1: Mobile Pull-to-Refresh (Primary)
- Add `RefreshIndicator` wrapper to mobile board
- Implement `_handleRefresh` callback
- Test on iOS and Android

### Phase 2: Desktop Refresh Button (Optional Enhancement)
- Add refresh button to desktop header row
- Show loading state in button
- Test on web and desktop platforms

## Edge Cases

1. **Rapid Pulls**: `RefreshIndicator` handles this internally; only one refresh at a time
2. **Network Errors**: Error state is handled by existing `_buildError` widget
3. **Empty State**: Works correctly; AlwaysScrollableScrollPhysics ensures gesture works
4. **Screen Rotation**: Layout adapts; RefreshIndicator remains functional

## Security Considerations

No security implications - this feature only triggers existing API calls that are already authenticated and rate-limited on the server side.

## Performance Considerations

1. **Debouncing**: The `RefreshIndicator` prevents multiple simultaneous refreshes
2. **Cache Usage**: The provider already caches data locally; fresh data merges with cache
3. **WebSocket Sync**: Real-time updates via WebSocket continue; manual refresh is supplementary
