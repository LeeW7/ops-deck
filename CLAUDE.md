# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent Command Center is a Flutter mobile application that serves as a monitoring dashboard for a custom Python-based Agent Server. It displays job statuses, allows viewing real-time logs, and receives push notifications via Firebase Cloud Messaging.

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
Uses Provider pattern with three main providers defined in `lib/providers/job_provider.dart`:
- **JobProvider**: Manages job list state, polls `/api/status` every 2 seconds
- **LogProvider**: Manages log viewing for a specific job, polls `/api/logs/<issueId>` every 1 second
- **SettingsProvider**: Manages server URL configuration stored in SharedPreferences

### Data Flow
1. `ApiService` (`lib/services/api_service.dart`) handles all HTTP communication with the agent server
2. Server base URL is stored locally via SharedPreferences
3. Providers are initialized in `main.dart` via `MultiProvider`

### Screen Navigation
- **DashboardScreen**: Main screen showing job list, starts polling on load if configured
- **LogScreen**: Displays real-time logs for a selected job with auto-scroll
- **SettingsScreen**: Configure and test server connection

### API Endpoints Expected
The app expects these endpoints from the agent server:
- `GET /api/status` - Returns job statuses (array or object format)
- `GET /api/logs/<issueId>` - Returns `{ "logs": "..." }` for a specific job

### Job Model
Jobs are identified by `issueId` (String) and have statuses: running, failed, pending, completed, unknown. The model handles both array and object response formats from the API.

### Firebase Integration
Firebase Messaging is initialized in `main.dart` for push notifications. The app gracefully continues without Firebase if initialization fails (useful for development).
