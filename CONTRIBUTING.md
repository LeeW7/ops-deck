# Contributing to Ops Deck

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ops-deck.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Push and create a Pull Request

## Development Setup

### Prerequisites

- Flutter SDK 3.29.0 or later
- Dart SDK (included with Flutter)
- Android Studio or VS Code with Flutter extensions
- For iOS: macOS with Xcode

### Building

```bash
# Get dependencies
flutter pub get

# Run analysis
flutter analyze

# Run tests
flutter test

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release
```

### Firebase Setup (Optional)

For push notifications:
1. Create a Firebase project
2. Add your `google-services.json` to `android/app/`
3. Add your `GoogleService-Info.plist` to `ios/Runner/`

These files are gitignored and should never be committed.

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Run `flutter analyze` before committing
- Use meaningful variable and function names
- Keep widgets focused and small

## Pull Request Process

1. Ensure `flutter analyze` passes with no errors
2. Test on at least one platform (Android or iOS)
3. Update documentation if needed
4. Fill out the PR template completely
5. Link any related issues

## Reporting Bugs

Use the GitHub issue tracker with the Bug Report template. Include:
- Clear description of the issue
- Steps to reproduce
- Device and OS version
- Screenshots if applicable

## Security

Please report security vulnerabilities privately. See [SECURITY.md](SECURITY.md) for details.

## Questions?

Open a GitHub Discussion or Issue for questions about contributing.
