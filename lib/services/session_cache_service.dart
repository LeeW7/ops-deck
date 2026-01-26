import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_model.dart';
import '../models/message_model.dart';

/// Local SQLite cache for quick sessions and messages
/// Enables instant app startup and offline viewing of session history
class SessionCacheService {
  static const String _dbName = 'quick_sessions_cache.db';
  static const int _dbVersion = 1;

  Database? _database;

  /// Get the database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    if (kDebugMode) {
      print('[SessionCache] Initializing database at $path');
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Quick sessions table
    await db.execute('''
      CREATE TABLE quick_sessions (
        id TEXT PRIMARY KEY,
        repo TEXT NOT NULL,
        status TEXT NOT NULL,
        worktree_path TEXT,
        claude_session_id TEXT,
        created_at INTEGER NOT NULL,
        last_activity INTEGER NOT NULL,
        message_count INTEGER NOT NULL DEFAULT 0,
        total_cost_usd REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sessions_repo ON quick_sessions(repo)
    ''');

    await db.execute('''
      CREATE INDEX idx_sessions_last_activity ON quick_sessions(last_activity DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_sessions_status ON quick_sessions(status)
    ''');

    // Quick messages table with foreign key to sessions
    await db.execute('''
      CREATE TABLE quick_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        cost_usd REAL,
        tool_name TEXT,
        tool_input TEXT,
        FOREIGN KEY (session_id) REFERENCES quick_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_session ON quick_messages(session_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp ON quick_messages(timestamp ASC)
    ''');

    if (kDebugMode) {
      print('[SessionCache] Database created with version $version');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('[SessionCache] Upgrading database from $oldVersion to $newVersion');
    }

    // Future migrations go here
    // if (oldVersion < 2) { ... }
  }

  // ============================================================================
  // Session Methods
  // ============================================================================

  /// Save a session to the cache (insert or update)
  Future<void> saveSession(QuickSession session) async {
    final db = await database;

    await db.insert(
      'quick_sessions',
      _sessionToMap(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (kDebugMode) {
      print('[SessionCache] Saved session: ${session.id}');
    }
  }

  /// Save multiple sessions to the cache (batch operation)
  Future<void> saveSessions(List<QuickSession> sessions) async {
    if (sessions.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final session in sessions) {
        batch.insert(
          'quick_sessions',
          _sessionToMap(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    if (kDebugMode) {
      print('[SessionCache] Saved ${sessions.length} sessions to cache');
    }
  }

  /// Get all cached sessions
  Future<List<QuickSession>> getAllSessions() async {
    final db = await database;

    final maps = await db.query(
      'quick_sessions',
      orderBy: 'last_activity DESC',
    );

    return maps.map(_sessionFromMap).toList();
  }

  /// Get sessions for a specific repository
  Future<List<QuickSession>> getSessionsForRepo(String repo) async {
    final db = await database;

    final maps = await db.query(
      'quick_sessions',
      where: 'repo = ?',
      whereArgs: [repo],
      orderBy: 'last_activity DESC',
    );

    return maps.map(_sessionFromMap).toList();
  }

  /// Get a single session by ID
  Future<QuickSession?> getSession(String id) async {
    final db = await database;

    final maps = await db.query(
      'quick_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _sessionFromMap(maps.first);
  }

  /// Delete a session and its messages
  Future<void> deleteSession(String id) async {
    final db = await database;

    await db.transaction((txn) async {
      // Delete messages first (foreign key constraint)
      await txn.delete(
        'quick_messages',
        where: 'session_id = ?',
        whereArgs: [id],
      );

      // Delete the session
      await txn.delete(
        'quick_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    if (kDebugMode) {
      print('[SessionCache] Deleted session: $id');
    }
  }

  /// Delete old sessions based on age and count limits per repo
  Future<int> deleteOldSessions({
    Duration maxAge = const Duration(hours: 24),
    int maxPerRepo = 10,
  }) async {
    final db = await database;
    int totalDeleted = 0;

    // First, delete sessions older than maxAge
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    // Get IDs of sessions to delete by age
    final oldSessions = await db.query(
      'quick_sessions',
      columns: ['id'],
      where: 'last_activity < ?',
      whereArgs: [cutoff],
    );

    if (oldSessions.isNotEmpty) {
      final oldIds = oldSessions.map((m) => m['id'] as String).toList();

      await db.transaction((txn) async {
        // Delete messages for old sessions
        for (final id in oldIds) {
          await txn.delete(
            'quick_messages',
            where: 'session_id = ?',
            whereArgs: [id],
          );
        }

        // Delete the old sessions
        final placeholders = List.filled(oldIds.length, '?').join(', ');
        totalDeleted += await txn.rawDelete(
          'DELETE FROM quick_sessions WHERE id IN ($placeholders)',
          oldIds,
        );
      });
    }

    // Second, enforce maxPerRepo limit for each repository
    final repos = await db.rawQuery(
      'SELECT DISTINCT repo FROM quick_sessions',
    );

    for (final repoRow in repos) {
      final repo = repoRow['repo'] as String;

      // Get sessions for this repo, ordered by last activity
      final repoSessions = await db.query(
        'quick_sessions',
        columns: ['id'],
        where: 'repo = ?',
        whereArgs: [repo],
        orderBy: 'last_activity DESC',
      );

      if (repoSessions.length > maxPerRepo) {
        // Get IDs of sessions to delete (keep first maxPerRepo)
        final sessionsToDelete = repoSessions.skip(maxPerRepo).toList();
        final idsToDelete =
            sessionsToDelete.map((m) => m['id'] as String).toList();

        await db.transaction((txn) async {
          for (final id in idsToDelete) {
            await txn.delete(
              'quick_messages',
              where: 'session_id = ?',
              whereArgs: [id],
            );
          }

          final placeholders = List.filled(idsToDelete.length, '?').join(', ');
          totalDeleted += await txn.rawDelete(
            'DELETE FROM quick_sessions WHERE id IN ($placeholders)',
            idsToDelete,
          );
        });
      }
    }

    if (kDebugMode && totalDeleted > 0) {
      print('[SessionCache] Deleted $totalDeleted old sessions');
    }

    return totalDeleted;
  }

  // ============================================================================
  // Message Methods
  // ============================================================================

  /// Save a message to the cache
  Future<void> saveMessage(QuickMessage message) async {
    final db = await database;

    await db.insert(
      'quick_messages',
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (kDebugMode) {
      print('[SessionCache] Saved message: ${message.id}');
    }
  }

  /// Save multiple messages to the cache (batch operation)
  Future<void> saveMessages(List<QuickMessage> messages) async {
    if (messages.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final message in messages) {
        batch.insert(
          'quick_messages',
          _messageToMap(message),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    if (kDebugMode) {
      print('[SessionCache] Saved ${messages.length} messages to cache');
    }
  }

  /// Get all messages for a session
  Future<List<QuickMessage>> getMessagesForSession(String sessionId) async {
    final db = await database;

    final maps = await db.query(
      'quick_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return maps.map(_messageFromMap).toList();
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Clear all cached data (for debugging/testing)
  Future<void> clearAllData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('quick_messages');
      await txn.delete('quick_sessions');
    });

    if (kDebugMode) {
      print('[SessionCache] All data cleared');
    }
  }

  /// Get session count
  Future<int> getSessionCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM quick_sessions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get message count
  Future<int> getMessageCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM quick_messages');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ============================================================================
  // Conversion helpers
  // ============================================================================

  Map<String, dynamic> _sessionToMap(QuickSession session) {
    return {
      'id': session.id,
      'repo': session.repo,
      'status': session.status.name,
      'worktree_path': session.worktreePath,
      'claude_session_id': session.claudeSessionId,
      'created_at': session.createdAt.millisecondsSinceEpoch,
      'last_activity': session.lastActivity.millisecondsSinceEpoch,
      'message_count': session.messageCount,
      'total_cost_usd': session.totalCostUsd,
    };
  }

  QuickSession _sessionFromMap(Map<String, dynamic> map) {
    return QuickSession(
      id: map['id'] as String,
      repo: map['repo'] as String,
      status: SessionStatus.fromString(map['status'] as String),
      worktreePath: map['worktree_path'] as String?,
      claudeSessionId: map['claude_session_id'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastActivity:
          DateTime.fromMillisecondsSinceEpoch(map['last_activity'] as int),
      messageCount: map['message_count'] as int,
      totalCostUsd: (map['total_cost_usd'] as num).toDouble(),
    );
  }

  Map<String, dynamic> _messageToMap(QuickMessage message) {
    return {
      'id': message.id,
      'session_id': message.sessionId,
      'role': message.role.name,
      'content': message.content,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'cost_usd': message.costUsd,
      'tool_name': message.toolName,
      'tool_input': message.toolInput,
    };
  }

  QuickMessage _messageFromMap(Map<String, dynamic> map) {
    return QuickMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: MessageRole.fromString(map['role'] as String),
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      costUsd: (map['cost_usd'] as num?)?.toDouble(),
      toolName: map['tool_name'] as String?,
      toolInput: map['tool_input'] as String?,
    );
  }
}
