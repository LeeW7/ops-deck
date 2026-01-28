# Pull to Refresh - Architecture Document

## Overview

Add pull-to-refresh functionality to the Kanban board home page, allowing users to manually trigger a data refresh by pulling down on the mobile view.

## Approach

Flutter's `RefreshIndicator` widget provides native pull-to-refresh behavior. This will be wrapped around the existing scrollable content in the mobile board view. On desktop/tablet, the pull-to-refresh gesture is less intuitive, so we'll optionally add a manual refresh button.

## Implementation Details

### Widget Structure

```
KanbanBoardScreen
└── Scaffold
    └── body: Consumer<IssueBoardProvider>
        └── _buildBoard()
            ├── Mobile (< 600px):
            │   └── RefreshIndicator  ← NEW
            │       └── Column
            │           ├── DoneColumnHeader
            │           └── Expanded(PageView)
            │
            └── Desktop (>= 600px):
                └── Column
                    ├── RefreshRow  ← NEW (optional)
                    ├── DoneColumnHeader
                    └── Expanded(Row of columns)
```

### Key Changes

1. **Mobile View (`_buildMobileBoard`)**:
   - Wrap the `Column` in a `RefreshIndicator`
   - The `onRefresh` callback calls `provider.fetchJobs()`
   - Uses Material Design refresh indicator styling

2. **Desktop View (`_buildDesktopBoard`)** (optional enhancement):
   - Add a refresh button row above the Done header
   - Shows last updated timestamp
   - Button triggers same `fetchJobs()` method

### Data Flow

```
User pulls down
    ↓
RefreshIndicator.onRefresh()
    ↓
IssueBoardProvider.fetchJobs()
    ↓
ApiService.fetchStatus()
    ↓
HTTP GET /api/status
    ↓
Update _issues map
    ↓
notifyListeners()
    ↓
UI rebuilds with fresh data
```

## Code Changes

### File: `lib/screens/kanban_board_screen.dart`

**Change 1**: Modify `_buildMobileBoard` to wrap content in `RefreshIndicator`:

```dart
Widget _buildMobileBoard(BuildContext context, IssueBoardProvider provider) {
  return RefreshIndicator(
    onRefresh: () => provider.fetchJobs(),
    color: Theme.of(context).colorScheme.primary,
    child: Column(
      children: [
        // ... existing content
      ],
    ),
  );
}
```

**Note**: The `Column` needs to be scrollable for `RefreshIndicator` to work. Options:
- Wrap in `SingleChildScrollView` with `AlwaysScrollableScrollPhysics`
- Use `CustomScrollView` with slivers

**Preferred approach**: Use `CustomScrollView` for better performance:

```dart
Widget _buildMobileBoard(BuildContext context, IssueBoardProvider provider) {
  return RefreshIndicator(
    onRefresh: () => provider.fetchJobs(),
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: DoneColumnHeader(...),
        ),
        SliverFillRemaining(
          child: PageView.builder(...),
        ),
      ],
    ),
  );
}
```

## Testing Strategy

### Manual Testing
1. Open app on mobile device/emulator
2. Navigate to Kanban board
3. Pull down from top of screen
4. Verify refresh indicator appears
5. Verify data refreshes after release
6. Verify indicator dismisses when complete

### Widget Tests
```dart
testWidgets('pull to refresh triggers fetchJobs', (tester) async {
  final provider = MockIssueBoardProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider<IssueBoardProvider>.value(
      value: provider,
      child: MaterialApp(home: KanbanBoardScreen()),
    ),
  );

  // Trigger pull to refresh
  await tester.fling(find.byType(RefreshIndicator), Offset(0, 300), 1000);
  await tester.pumpAndSettle();

  verify(provider.fetchJobs()).called(1);
});
```

## Considerations

1. **Already refreshing**: The provider already has `isLoading` state. The `RefreshIndicator` will show its own loading indicator while `fetchJobs()` is in progress.

2. **Error handling**: Errors from `fetchJobs()` are already handled by the provider and displayed in the UI.

3. **WebSocket updates**: The app already uses WebSocket for real-time updates. Pull-to-refresh is a manual fallback for users who want to ensure fresh data.

4. **Offline state**: If the device is offline, the refresh will fail and the existing error UI will display.

## Implementation Phases

### Phase 1: Core Pull-to-Refresh (Required)
- Add `RefreshIndicator` wrapper to mobile view
- Connect to existing `fetchJobs()` method
- Test on mobile devices

### Phase 2: Polish (Optional)
- Add refresh button for desktop view
- Show "last updated" timestamp
- Custom refresh indicator styling to match app theme
