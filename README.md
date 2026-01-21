# Ops Deck

A Flutter mobile app for managing Claude Code agents and GitHub issue workflows.

## Features

- **Issue Creation**: Create GitHub issues with AI-enhanced descriptions
- **Kanban Board**: Visual workflow tracking (Plan → Implement → Review → Done)
- **Job Monitoring**: Real-time status updates for running agents
- **Approval Flow**: Approve or reject jobs that need user confirmation
- **Push Notifications**: Firebase Cloud Messaging for job status alerts
- **Multi-Repository**: Support for multiple GitHub repositories

## Requirements

- Flutter 3.x
- Firebase project (for push notifications)
- Claude Ops server running

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/ops-deck.git
   cd ops-deck
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - See [SETUP.md](SETUP.md) for detailed Firebase configuration
   - Copy your `google-services.json` to `android/app/`
   - Copy your `GoogleService-Info.plist` to `ios/Runner/`

4. **Run the app**
   ```bash
   flutter run
   ```

5. **Configure server URL**
   - Open Settings in the app
   - Enter your Claude Ops server URL (e.g., `http://192.168.1.x:5001`)

## Building

### Android
```bash
flutter build apk
# or for release
flutter build apk --release
```

### iOS
```bash
flutter build ios
# Then archive in Xcode for distribution
```

### Web
```bash
flutter build web
```

## Configuration

### Server Connection

The app connects to a Claude Ops server for:
- Job status and logs
- Creating issues
- Approving/rejecting jobs

Configure the server URL in Settings.

### Push Notifications

Push notifications require:
1. Firebase project configuration
2. Claude Ops server with matching Firebase credentials

See [SETUP.md](SETUP.md) for detailed setup instructions.

## App Structure

```
lib/
├── main.dart                 # App entry point
├── providers/                # State management
│   ├── job_provider.dart     # Job/log state
│   └── issue_board_provider.dart  # Kanban board state
└── screens/                  # UI screens
    ├── kanban_board_screen.dart
    └── settings_screen.dart
```

## Workflow

1. **Create Issue**: Use the app to create a new GitHub issue
2. **AI Enhancement**: Optionally enhance the description with Gemini
3. **Auto-Label**: Issues are automatically labeled to trigger agents
4. **Monitor**: Watch job progress in real-time
5. **Approve/Reject**: Interact with jobs that need user input
6. **Review**: See completed work in the kanban board

## Companion Server

Ops Deck requires [Claude Ops](https://github.com/YOUR_USERNAME/claude-ops) server running on your local machine or network.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
