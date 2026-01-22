import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/job_model.dart';

/// Local SQLite cache for jobs
/// Enables instant app startup and offline viewing
class JobCacheService {
  static const String _dbName = 'ops_deck_cache.db';
  static const int _dbVersion = 1;

  Database? _database;
  DateTime? _lastSyncTime;

  /// Get the database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Get the last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    if (kDebugMode) {
      print('[JobCache] Initializing database at $path');
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE jobs (
        issue_id TEXT PRIMARY KEY,
        repo TEXT NOT NULL,
        repo_slug TEXT NOT NULL,
        issue_num INTEGER NOT NULL,
        issue_title TEXT NOT NULL,
        command TEXT NOT NULL,
        status TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        completed_time INTEGER,
        error TEXT,
        log_path TEXT NOT NULL,
        local_path TEXT NOT NULL,
        full_command TEXT NOT NULL,
        cost_total_usd REAL,
        cost_input_tokens INTEGER,
        cost_output_tokens INTEGER,
        cost_cache_read_tokens INTEGER,
        cost_cache_creation_tokens INTEGER,
        cost_model TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_jobs_status ON jobs(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_jobs_start_time ON jobs(start_time DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_jobs_repo_issue ON jobs(repo, issue_num)
    ''');

    // Metadata table for tracking sync state
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    if (kDebugMode) {
      print('[JobCache] Database created with version $version');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
    if (kDebugMode) {
      print('[JobCache] Upgrading database from $oldVersion to $newVersion');
    }
  }

  /// Save a job to the cache
  Future<void> saveJob(Job job) async {
    final db = await database;

    await db.insert(
      'jobs',
      _jobToMap(job),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple jobs to the cache (batch operation)
  Future<void> saveJobs(List<Job> jobs) async {
    if (jobs.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final job in jobs) {
        batch.insert(
          'jobs',
          _jobToMap(job),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    if (kDebugMode) {
      print('[JobCache] Saved ${jobs.length} jobs to cache');
    }
  }

  /// Get all cached jobs
  Future<List<Job>> getAllJobs() async {
    final db = await database;

    final maps = await db.query(
      'jobs',
      orderBy: 'start_time DESC',
    );

    return maps.map(_jobFromMap).toList();
  }

  /// Get jobs for a specific issue
  Future<List<Job>> getJobsForIssue(String repo, int issueNum) async {
    final db = await database;

    final maps = await db.query(
      'jobs',
      where: 'repo = ? AND issue_num = ?',
      whereArgs: [repo, issueNum],
      orderBy: 'start_time DESC',
    );

    return maps.map(_jobFromMap).toList();
  }

  /// Get a single job by ID
  Future<Job?> getJob(String issueId) async {
    final db = await database;

    final maps = await db.query(
      'jobs',
      where: 'issue_id = ?',
      whereArgs: [issueId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _jobFromMap(maps.first);
  }

  /// Update a job's status
  Future<void> updateJobStatus(String issueId, String status) async {
    final db = await database;

    await db.update(
      'jobs',
      {
        'status': status,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'issue_id = ?',
      whereArgs: [issueId],
    );
  }

  /// Delete old jobs (keep last N days)
  Future<int> deleteOldJobs({int keepDays = 30}) async {
    final db = await database;

    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch ~/
        1000;

    final count = await db.delete(
      'jobs',
      where: 'start_time < ?',
      whereArgs: [cutoff],
    );

    if (kDebugMode && count > 0) {
      print('[JobCache] Deleted $count old jobs');
    }

    return count;
  }

  /// Clear all cached jobs
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('jobs');
    await db.delete('metadata');
    _lastSyncTime = null;

    if (kDebugMode) {
      print('[JobCache] Cache cleared');
    }
  }

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    final db = await database;
    _lastSyncTime = DateTime.now();

    await db.insert(
      'metadata',
      {'key': 'last_sync_time', 'value': _lastSyncTime!.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load last sync time from storage
  Future<DateTime?> loadLastSyncTime() async {
    final db = await database;

    final result = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['last_sync_time'],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final value = result.first['value'] as String?;
    if (value == null) return null;

    _lastSyncTime = DateTime.tryParse(value);
    return _lastSyncTime;
  }

  /// Get job count
  Future<int> getJobCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM jobs');
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

  Map<String, dynamic> _jobToMap(Job job) {
    return {
      'issue_id': job.issueId,
      'repo': job.repo,
      'repo_slug': job.repoSlug,
      'issue_num': job.issueNum,
      'issue_title': job.issueTitle,
      'command': job.command,
      'status': job.status,
      'start_time': job.startTime,
      'completed_time': job.completedTime,
      'error': job.error,
      'log_path': job.logPath,
      'local_path': job.localPath,
      'full_command': job.fullCommand,
      'cost_total_usd': job.cost?.totalUsd,
      'cost_input_tokens': job.cost?.inputTokens,
      'cost_output_tokens': job.cost?.outputTokens,
      'cost_cache_read_tokens': job.cost?.cacheReadTokens,
      'cost_cache_creation_tokens': job.cost?.cacheCreationTokens,
      'cost_model': job.cost?.model,
      'created_at': job.createdAt.millisecondsSinceEpoch,
      'updated_at': job.updatedAt.millisecondsSinceEpoch,
    };
  }

  Job _jobFromMap(Map<String, dynamic> map) {
    JobCost? cost;
    if (map['cost_total_usd'] != null) {
      cost = JobCost(
        totalUsd: (map['cost_total_usd'] as num).toDouble(),
        inputTokens: map['cost_input_tokens'] as int? ?? 0,
        outputTokens: map['cost_output_tokens'] as int? ?? 0,
        cacheReadTokens: map['cost_cache_read_tokens'] as int? ?? 0,
        cacheCreationTokens: map['cost_cache_creation_tokens'] as int? ?? 0,
        model: map['cost_model'] as String? ?? 'unknown',
      );
    }

    return Job(
      issueId: map['issue_id'] as String,
      repo: map['repo'] as String,
      repoSlug: map['repo_slug'] as String,
      issueNum: map['issue_num'] as int,
      issueTitle: map['issue_title'] as String,
      command: map['command'] as String,
      status: map['status'] as String,
      startTime: map['start_time'] as int,
      completedTime: map['completed_time'] as int?,
      error: map['error'] as String?,
      logPath: map['log_path'] as String,
      localPath: map['local_path'] as String,
      fullCommand: map['full_command'] as String,
      cost: cost,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
