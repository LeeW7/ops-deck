import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/job_provider.dart';
import 'providers/issue_board_provider.dart';
import 'providers/quick_session_provider.dart';
import 'providers/preview_provider.dart';
import 'screens/kanban_board_screen.dart';
import 'screens/issue_detail_screen.dart';
import 'services/notification_service.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('Background message received: ${message.messageId}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
    // Continue without Firebase if it fails (for development)
  }

  runApp(const OpsDeckApp());
}

class OpsDeckApp extends StatefulWidget {
  const OpsDeckApp({super.key});

  @override
  State<OpsDeckApp> createState() => _OpsDeckAppState();
}

class _OpsDeckAppState extends State<OpsDeckApp> with WidgetsBindingObserver {
  /// Global navigator key for notification deep linking
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFirebaseMessaging();
    _setupNotificationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notificationService = NotificationService();

    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        notificationService.isInForeground = true;
        if (kDebugMode) {
          print('[OpsDeckApp] App resumed - refreshing data');
        }
        // Trigger data refresh
        _refreshDataOnResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App went to background
        notificationService.isInForeground = false;
        if (kDebugMode) {
          print('[OpsDeckApp] App paused/inactive');
        }
        break;
      case AppLifecycleState.detached:
        // App is detached
        break;
    }
  }

  void _refreshDataOnResume() {
    // Get the IssueBoardProvider and refresh
    final context = _navigatorKey.currentContext;
    if (context != null) {
      try {
        final provider = Provider.of<IssueBoardProvider>(context, listen: false);
        provider.fetchJobs();
      } catch (e) {
        if (kDebugMode) {
          print('[OpsDeckApp] Failed to refresh on resume: $e');
        }
      }
    }
  }

  Future<void> _setupNotificationService() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Handle notification taps - navigate to issue detail
    notificationService.onNotificationTap = (repo, issueNum) {
      if (kDebugMode) {
        print('[OpsDeckApp] Notification tap: $repo #$issueNum');
      }
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => IssueDetailScreen(
            repo: repo,
            issueNum: issueNum,
          ),
        ),
      );
    };
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token (useful for debugging)
      await messaging.getToken();

      // Subscribe to the "all" topic to receive server notifications
      await messaging.subscribeToTopic('all');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase Messaging setup failed: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message: ${message.notification?.title}');
    }

    // Show snackbar when app is in foreground
    if (message.notification != null && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.notification?.title != null)
                  Text(
                    message.notification!.title!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (message.notification?.body != null)
                  Text(
                    message.notification!.body!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF238636),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('App opened from notification: ${message.data}');
    }
    // Handle navigation based on message data if needed
    // For example, navigate to a specific job's log screen
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => IssueProvider()),
        ChangeNotifierProvider(create: (_) => IssueBoardProvider()),
        ChangeNotifierProvider(create: (_) => QuickSessionProvider()),
        ChangeNotifierProvider(create: (_) => PreviewProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Ops Deck',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const KanbanBoardScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      primaryColor: const Color(0xFF00FF41),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FF41),
        secondary: Color(0xFF238636),
        surface: Color(0xFF161B22),
        error: Color(0xFFF85149),
        onPrimary: Color(0xFF0D1117),
        onSecondary: Colors.white,
        onSurface: Color(0xFFE6EDF3),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Color(0xFF00FF41),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00FF41),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF238636),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00FF41),
          side: const BorderSide(color: Color(0xFF00FF41)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF00FF41),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00FF41)),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF8B949E),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF8B949E),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF161B22),
        contentTextStyle: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFFE6EDF3),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF00FF41),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF8B949E),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF30363D),
      ),
    );
  }
}
