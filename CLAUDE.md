# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ops Deck is a Flutter mobile app for managing Claude Code agents and GitHub issue workflows. It provides a Kanban board for tracking issues through Plan → Implement → Review → Done phases, with real-time job monitoring, push notifications, and an approval flow for jobs that need user confirmation.

## Build and Development Commands

```bash
# Get dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device_id>

# Build release APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/<filename>_test.dart
```

## Architecture

### State Management
Uses Provider pattern with five providers initialized in `main.dart` via `MultiProvider`:

- **JobProvider** (`lib/providers/job_provider.dart`): Manages job list state, polls `/api/status` every 15 seconds (HTTP polling fallback)
- **LogProvider** (`lib/providers/job_provider.dart`): Manages log viewing for a specific job, polls every 10 seconds
- **SettingsProvider** (`lib/providers/job_provider.dart`): Manages server URL configuration stored in SharedPreferences
- **IssueProvider** (`lib/providers/job_provider.dart`): Handles issue creation and AI enhancement
- **IssueBoardProvider** (`lib/providers/issue_board_provider.dart`): Main provider for the Kanban board, aggregates jobs into issues

### Real-Time Updates
Two-tier update strategy:
1. **WebSocket (primary)**: `GlobalEventsService` in `lib/services/websocket_service.dart` connects to `/ws/events` for instant job lifecycle updates
2. **HTTP polling (backup)**: Falls back to `/api/status` every 60 seconds if WebSocket fails
3. **SQLite cache**: `JobCacheService` provides instant startup by loading cached jobs locally

### Data Flow
1. `ApiService` (`lib/services/api_service.dart`) handles all HTTP communication with retry logic and typed error handling
2. Server base URL stored in SharedPreferences
3. Jobs are aggregated into `Issue` objects by `IssueBoardProvider` for Kanban display
4. Issue status derived from constituent job statuses (running, failed, needs_action, done)

### Key Models
- **Job** (`lib/models/job_model.dart`): Individual job with status, cost tracking, and timestamps
- **Issue** (`lib/models/issue_model.dart`): Aggregated view of all jobs for a single GitHub issue, tracks workflow phase

### Screen Structure
- **KanbanBoardScreen**: Main screen with horizontal scrolling columns (Needs Action, Running, Failed, Done)
- **IssueDetailScreen**: Shows issue workflow state, job history, and action buttons
- **LogScreen**: Real-time job logs with WebSocket streaming
- **CreateIssueScreen**: Create issues with optional AI enhancement
- **SettingsScreen**: Configure server URL

### API Endpoints Expected
The app expects these endpoints from the Claude Ops server:
- `GET /api/status` - Returns all jobs (array or object format)
- `GET /api/logs/<jobId>` - Returns `{ "logs": "..." }` for a job
- `POST /approve` - Approve a waiting job
- `POST /reject` - Reject a waiting job
- `GET /repos` - List configured repositories
- `POST /issues/create` - Create a GitHub issue
- `POST /issues/enhance` - AI-enhance issue description
- `POST /jobs/trigger` - Trigger a specific job command
- `GET /issues/<repo>/<issueNum>/workflow` - Get issue workflow state
- `WS /ws/events` - Global job events stream
- `WS /ws/jobs/<jobId>` - Job-specific log stream

### Firebase Integration
Firebase Messaging for push notifications, initialized in `main.dart`. The app gracefully continues without Firebase if initialization fails.
