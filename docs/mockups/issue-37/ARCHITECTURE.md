# Architecture: Add App Version to Settings Screen

## Overview

This feature displays the app version number from `pubspec.yaml` on the Settings screen. Flutter provides built-in support for reading package information at runtime via the `package_info_plus` package.

## Approach

### Option 1: package_info_plus (Recommended)

Use the `package_info_plus` package which provides platform-aware version information at runtime.

**Pros:**
- Works across all platforms (iOS, Android, web, desktop)
- Provides version, build number, app name, and package name
- Maintained by Flutter community
- Handles platform-specific version retrieval automatically

**Cons:**
- Adds a dependency
- Async initialization required

### Option 2: Hardcode version constant

Define a constant that mirrors the pubspec.yaml version.

**Pros:**
- No additional dependency
- Synchronous access

**Cons:**
- Must be manually updated when version changes
- Risk of version mismatch between constant and pubspec.yaml

### Chosen Approach: package_info_plus

The `package_info_plus` package is the standard solution and ensures version consistency.

## Data Model

The `PackageInfo` class from `package_info_plus` provides:

```dart
class PackageInfo {
  final String appName;      // "Ops Deck"
  final String packageName;  // "com.example.ops_deck"
  final String version;      // "1.0.0"
  final String buildNumber;  // "1"
}
```

Display format: `{version}+{buildNumber}` (e.g., "1.0.0+1")

## Implementation

### Files to Modify

1. **pubspec.yaml** - Add `package_info_plus` dependency
2. **lib/screens/settings_screen.dart** - Add version display widget

### Code Changes

#### pubspec.yaml

```yaml
dependencies:
  # ... existing dependencies
  package_info_plus: ^8.0.0
```

#### settings_screen.dart

Add an "ABOUT" section after the existing "INFO" section with a version display row.

```dart
// In _SettingsScreenState class:
PackageInfo? _packageInfo;

@override
void initState() {
  super.initState();
  _initPackageInfo();
  // ... existing code
}

Future<void> _initPackageInfo() async {
  final info = await PackageInfo.fromPlatform();
  if (mounted) {
    setState(() => _packageInfo = info);
  }
}

// In build method, add after _buildInfoSection():
Widget _buildAboutSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader('ABOUT'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'App Version',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFF8B949E),
              ),
            ),
            Text(
              _packageInfo != null
                  ? '${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                  : '...',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

## UI Design

The version is displayed in a container that matches the existing Settings screen design:
- Dark background (`#161B22`)
- Border with `#30363D`
- Label in secondary color (`#8B949E`)
- Version number in accent green (`#00FF41`)
- Monospace font family consistent with the rest of the app

## Security Considerations

- Version information is not sensitive
- No user data involved
- Read-only operation

## Testing Strategy

### Unit Tests

None required - this is a simple display feature using a well-tested package.

### Widget Tests

```dart
testWidgets('displays app version', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [/* mock providers */],
        child: const SettingsScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify ABOUT section exists
  expect(find.text('ABOUT'), findsOneWidget);
  expect(find.text('App Version'), findsOneWidget);
});
```

### Manual Testing

1. Navigate to Settings screen
2. Scroll to bottom
3. Verify "ABOUT" section header is visible
4. Verify "App Version" label with version number (e.g., "1.0.0+1") is displayed
5. Verify version matches pubspec.yaml

## Implementation Phases

### Phase 1: Add Package and Display Version (Single Phase)

1. Add `package_info_plus` dependency to pubspec.yaml
2. Run `flutter pub get`
3. Import package in settings_screen.dart
4. Add `_packageInfo` state variable
5. Add `_initPackageInfo()` method
6. Add `_buildAboutSection()` widget
7. Call `_buildAboutSection()` in build method after info section
8. Run `flutter analyze` to verify no issues
9. Test on device/emulator

## Dependencies

- **New**: `package_info_plus: ^8.0.0`

## Rollback Plan

If issues arise:
1. Remove version display widget from settings_screen.dart
2. Remove `package_info_plus` from pubspec.yaml
3. Run `flutter pub get`
