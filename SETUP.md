# Firebase Setup Guide

This guide explains how to configure Firebase for push notifications in Ops Deck.

## Prerequisites

- A Firebase project (create one at [Firebase Console](https://console.firebase.google.com))
- Flutter SDK installed
- FlutterFire CLI installed (`dart pub global activate flutterfire_cli`)

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" and follow the setup wizard
3. Enable Google Analytics (optional but recommended)

## Step 2: Add Android App

1. In Firebase Console, click "Add app" and select Android
2. Enter package name: `com.claudeops.opsdeck`
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`

## Step 3: Add iOS App (Optional)

1. In Firebase Console, click "Add app" and select iOS
2. Enter bundle ID: `com.claudeops.opsdeck`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`

## Step 4: Enable Cloud Messaging

1. In Firebase Console, go to Project Settings > Cloud Messaging
2. Note your Server Key for the Claude Ops server configuration

## Step 5: Configure iOS Push Notifications

For iOS, you also need to:

1. Enable Push Notifications capability in Xcode
2. Generate and upload APNs authentication key to Firebase

### Generate APNs Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Create a new key with APNs enabled
3. Download the `.p8` file
4. Upload to Firebase Console > Project Settings > Cloud Messaging > iOS app configuration

## Verification

After setup, the app should:

1. Request notification permissions on first launch
2. Subscribe to the "all" topic automatically
3. Receive push notifications from the Claude Ops server

## Troubleshooting

### Android
- Ensure `google-services.json` is in `android/app/`
- Verify package name matches in Firebase and `build.gradle.kts`

### iOS
- Ensure `GoogleService-Info.plist` is in `ios/Runner/` and added to Xcode project
- Verify APNs key is uploaded to Firebase
- Check that Push Notifications capability is enabled

## Server Configuration

The Claude Ops server needs a Firebase service account to send push notifications:

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Save as `service-account.json` in the Claude Ops server directory
