/// Model for tracking file changes from Edit/Write tool operations
class FileDiff {
  final String filePath;
  final String? oldContent;
  final String? newContent;
  final bool isNewFile;
  final DateTime timestamp;

  FileDiff({
    required this.filePath,
    this.oldContent,
    this.newContent,
    required this.isNewFile,
    required this.timestamp,
  });

  /// Extract just the filename from the path
  String get fileName => filePath.split('/').last;

  /// Get file extension
  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  /// Count lines added
  int get linesAdded {
    if (newContent == null) return 0;
    if (isNewFile) return newContent!.split('\n').length;
    final oldLines = oldContent?.split('\n').length ?? 0;
    final newLines = newContent!.split('\n').length;
    return newLines > oldLines ? newLines - oldLines : 0;
  }

  /// Count lines removed
  int get linesRemoved {
    if (oldContent == null || isNewFile) return 0;
    final oldLines = oldContent!.split('\n').length;
    final newLines = newContent?.split('\n').length ?? 0;
    return oldLines > newLines ? oldLines - newLines : 0;
  }

  /// Net line change
  int get netChange => linesAdded - linesRemoved;

  /// Create a unified diff representation
  List<DiffLine> get unifiedDiff {
    final lines = <DiffLine>[];

    if (isNewFile && newContent != null) {
      // All lines are additions
      for (final line in newContent!.split('\n')) {
        lines.add(DiffLine(DiffLineType.added, line));
      }
    } else if (oldContent != null && newContent != null) {
      // Simple line-by-line diff (not a sophisticated algorithm)
      final oldLines = oldContent!.split('\n');
      final newLines = newContent!.split('\n');

      // Find common prefix
      int commonPrefix = 0;
      while (commonPrefix < oldLines.length &&
          commonPrefix < newLines.length &&
          oldLines[commonPrefix] == newLines[commonPrefix]) {
        commonPrefix++;
      }

      // Find common suffix
      int commonSuffix = 0;
      while (commonSuffix < oldLines.length - commonPrefix &&
          commonSuffix < newLines.length - commonPrefix &&
          oldLines[oldLines.length - 1 - commonSuffix] ==
              newLines[newLines.length - 1 - commonSuffix]) {
        commonSuffix++;
      }

      // Add context lines before change
      final contextBefore = commonPrefix > 3 ? 3 : commonPrefix;
      if (commonPrefix > 3) {
        lines.add(DiffLine(DiffLineType.context, '... ${commonPrefix - 3} lines hidden ...'));
      }
      for (int i = commonPrefix - contextBefore; i < commonPrefix; i++) {
        lines.add(DiffLine(DiffLineType.unchanged, oldLines[i]));
      }

      // Add removed lines
      final removedEnd = oldLines.length - commonSuffix;
      for (int i = commonPrefix; i < removedEnd; i++) {
        lines.add(DiffLine(DiffLineType.removed, oldLines[i]));
      }

      // Add added lines
      final addedEnd = newLines.length - commonSuffix;
      for (int i = commonPrefix; i < addedEnd; i++) {
        lines.add(DiffLine(DiffLineType.added, newLines[i]));
      }

      // Add context lines after change
      final contextAfter = commonSuffix > 3 ? 3 : commonSuffix;
      final suffixStart = newLines.length - commonSuffix;
      for (int i = suffixStart; i < suffixStart + contextAfter; i++) {
        lines.add(DiffLine(DiffLineType.unchanged, newLines[i]));
      }
      if (commonSuffix > 3) {
        lines.add(DiffLine(DiffLineType.context, '... ${commonSuffix - 3} lines hidden ...'));
      }
    }

    return lines;
  }
}

/// Represents a single line in a diff
class DiffLine {
  final DiffLineType type;
  final String content;

  DiffLine(this.type, this.content);
}

/// Type of diff line
enum DiffLineType {
  added,
  removed,
  unchanged,
  context,
}

/// Aggregated diff summary for a job
class JobDiffSummary {
  final String jobId;
  final List<FileDiff> diffs;
  final DateTime lastUpdated;

  JobDiffSummary({
    required this.jobId,
    required this.diffs,
    required this.lastUpdated,
  });

  /// Total files changed
  int get fileCount => diffs.length;

  /// Total lines added across all files
  int get totalLinesAdded => diffs.fold(0, (sum, diff) => sum + diff.linesAdded);

  /// Total lines removed across all files
  int get totalLinesRemoved => diffs.fold(0, (sum, diff) => sum + diff.linesRemoved);

  /// Group diffs by directory
  Map<String, List<FileDiff>> get diffsByDirectory {
    final result = <String, List<FileDiff>>{};
    for (final diff in diffs) {
      final parts = diff.filePath.split('/');
      final dir = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : '/';
      result.putIfAbsent(dir, () => []).add(diff);
    }
    return result;
  }

  /// Add or update a diff for a file
  JobDiffSummary withDiff(FileDiff newDiff) {
    // Find existing diff for this file and merge or add
    final existingIndex = diffs.indexWhere((d) => d.filePath == newDiff.filePath);
    final updatedDiffs = List<FileDiff>.from(diffs);

    if (existingIndex >= 0) {
      // Merge: keep original old content, use new new content
      final existing = diffs[existingIndex];
      updatedDiffs[existingIndex] = FileDiff(
        filePath: newDiff.filePath,
        oldContent: existing.oldContent ?? newDiff.oldContent,
        newContent: newDiff.newContent,
        isNewFile: existing.isNewFile,
        timestamp: newDiff.timestamp,
      );
    } else {
      updatedDiffs.add(newDiff);
    }

    return JobDiffSummary(
      jobId: jobId,
      diffs: updatedDiffs,
      lastUpdated: DateTime.now(),
    );
  }

  /// Empty summary
  static JobDiffSummary empty(String jobId) => JobDiffSummary(
    jobId: jobId,
    diffs: [],
    lastUpdated: DateTime.now(),
  );
}
