import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback type for handling notification taps
typedef NotificationTapCallback = void Function(String repo, int issueNum);

/// Singleton service for local notifications
/// Shows notifications for job completion/failure events when app is in background
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Whether the app is currently in the foreground
  bool isInForeground = true;

  /// Callback for when user taps a notification
  NotificationTapCallback? onNotificationTap;

  /// Notification ID counter
  int _notificationId = 0;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    await _createAndroidChannel();

    // Request permissions on iOS
    await _requestPermissions();

    if (kDebugMode) {
      print('[NotificationService] Initialized');
    }
  }

  /// Create the Android notification channel for job events
  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'job_events',
      'Job Events',
      description: 'Notifications for job completion and failure events',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permissions on iOS
  Future<void> _requestPermissions() async {
    // iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('[NotificationService] Notification tapped: ${response.payload}');
    }

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // Parse payload: "repo|issueNum"
    final parts = payload.split('|');
    if (parts.length != 2) return;

    final repo = parts[0];
    final issueNum = int.tryParse(parts[1]);
    if (issueNum == null) return;

    // Invoke callback
    onNotificationTap?.call(repo, issueNum);
  }

  /// Show a notification for a job event
  /// [title] - e.g., "Job Completed" or "Job Failed"
  /// [body] - e.g., "#123: Feature implementation"
  /// [repo] - Repository for deep linking
  /// [issueNum] - Issue number for deep linking
  Future<void> showJobNotification({
    required String title,
    required String body,
    required String repo,
    required int issueNum,
  }) async {
    // Don't show if app is in foreground - snackbar will handle it
    if (isInForeground) {
      if (kDebugMode) {
        print('[NotificationService] Skipping notification (app in foreground)');
      }
      return;
    }

    final id = _notificationId++;
    final payload = '$repo|$issueNum';

    const androidDetails = AndroidNotificationDetails(
      'job_events',
      'Job Events',
      channelDescription: 'Notifications for job completion and failure events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );

    if (kDebugMode) {
      print('[NotificationService] Showed notification: $title - $body');
    }
  }

  /// Show a notification for job completion
  Future<void> showJobCompletedNotification({
    required String issueTitle,
    required int issueNum,
    required String repo,
    required String command,
  }) async {
    final commandLabel = _formatCommand(command);
    await showJobNotification(
      title: 'Job Completed',
      body: '#$issueNum: $issueTitle ($commandLabel)',
      repo: repo,
      issueNum: issueNum,
    );
  }

  /// Show a notification for job failure
  Future<void> showJobFailedNotification({
    required String issueTitle,
    required int issueNum,
    required String repo,
    required String command,
  }) async {
    final commandLabel = _formatCommand(command);
    await showJobNotification(
      title: 'Job Failed',
      body: '#$issueNum: $issueTitle ($commandLabel)',
      repo: repo,
      issueNum: issueNum,
    );
  }

  /// Format command name for display
  String _formatCommand(String command) {
    switch (command) {
      case 'plan-headless':
        return 'Plan';
      case 'implement-headless':
        return 'Implement';
      case 'revise-headless':
        return 'Revise';
      case 'retrospective-headless':
        return 'Retrospective';
      default:
        return command;
    }
  }
}
