import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/models/file_diff_model.dart';

void main() {
  group('FileDiff', () {
    test('fileName extracts just the filename from path', () {
      final diff = FileDiff(
        filePath: '/path/to/some/file.dart',
        oldContent: 'old',
        newContent: 'new',
        isNewFile: false,
        timestamp: DateTime.now(),
      );

      expect(diff.fileName, equals('file.dart'));
    });

    test('extension extracts file extension', () {
      final diff = FileDiff(
        filePath: '/path/to/file.dart',
        oldContent: null,
        newContent: 'content',
        isNewFile: true,
        timestamp: DateTime.now(),
      );

      expect(diff.extension, equals('dart'));
    });

    test('linesAdded counts new lines correctly for new file', () {
      final diff = FileDiff(
        filePath: 'test.dart',
        oldContent: null,
        newContent: 'line1\nline2\nline3',
        isNewFile: true,
        timestamp: DateTime.now(),
      );

      expect(diff.linesAdded, equals(3));
      expect(diff.linesRemoved, equals(0));
    });

    test('linesAdded and linesRemoved count correctly for edit', () {
      final diff = FileDiff(
        filePath: 'test.dart',
        oldContent: 'line1\nline2',
        newContent: 'line1\nline2\nline3\nline4',
        isNewFile: false,
        timestamp: DateTime.now(),
      );

      expect(diff.linesAdded, equals(2));
      expect(diff.linesRemoved, equals(0));
    });

    test('unifiedDiff generates correct diff lines for new file', () {
      final diff = FileDiff(
        filePath: 'test.dart',
        oldContent: null,
        newContent: 'line1\nline2',
        isNewFile: true,
        timestamp: DateTime.now(),
      );

      final lines = diff.unifiedDiff;
      expect(lines.length, equals(2));
      expect(lines[0].type, equals(DiffLineType.added));
      expect(lines[0].content, equals('line1'));
      expect(lines[1].type, equals(DiffLineType.added));
      expect(lines[1].content, equals('line2'));
    });

    test('unifiedDiff generates diff for edited file', () {
      final diff = FileDiff(
        filePath: 'test.dart',
        oldContent: 'unchanged\nold line\nunchanged2',
        newContent: 'unchanged\nnew line\nunchanged2',
        isNewFile: false,
        timestamp: DateTime.now(),
      );

      final lines = diff.unifiedDiff;
      // Should have: unchanged context, removed old line, added new line, unchanged2 context
      expect(lines.any((l) => l.type == DiffLineType.removed && l.content == 'old line'), isTrue);
      expect(lines.any((l) => l.type == DiffLineType.added && l.content == 'new line'), isTrue);
    });
  });

  group('JobDiffSummary', () {
    test('empty creates empty summary', () {
      final summary = JobDiffSummary.empty('job-123');

      expect(summary.jobId, equals('job-123'));
      expect(summary.diffs, isEmpty);
      expect(summary.fileCount, equals(0));
    });

    test('withDiff adds new diff', () {
      var summary = JobDiffSummary.empty('job-123');
      final diff = FileDiff(
        filePath: '/path/to/file.dart',
        oldContent: 'old',
        newContent: 'new',
        isNewFile: false,
        timestamp: DateTime.now(),
      );

      summary = summary.withDiff(diff);

      expect(summary.fileCount, equals(1));
      expect(summary.diffs[0].filePath, equals('/path/to/file.dart'));
    });

    test('withDiff merges diffs for same file', () {
      var summary = JobDiffSummary.empty('job-123');
      final diff1 = FileDiff(
        filePath: '/path/to/file.dart',
        oldContent: 'original',
        newContent: 'first edit',
        isNewFile: false,
        timestamp: DateTime.now(),
      );
      final diff2 = FileDiff(
        filePath: '/path/to/file.dart',
        oldContent: 'first edit',
        newContent: 'second edit',
        isNewFile: false,
        timestamp: DateTime.now(),
      );

      summary = summary.withDiff(diff1);
      summary = summary.withDiff(diff2);

      // Should still be one file
      expect(summary.fileCount, equals(1));
      // Should preserve original old content and use latest new content
      expect(summary.diffs[0].oldContent, equals('original'));
      expect(summary.diffs[0].newContent, equals('second edit'));
    });

    test('totalLinesAdded and totalLinesRemoved aggregate correctly', () {
      var summary = JobDiffSummary.empty('job-123');

      summary = summary.withDiff(FileDiff(
        filePath: 'file1.dart',
        oldContent: 'a',
        newContent: 'a\nb\nc',
        isNewFile: false,
        timestamp: DateTime.now(),
      ));

      summary = summary.withDiff(FileDiff(
        filePath: 'file2.dart',
        newContent: 'new file content',
        isNewFile: true,
        timestamp: DateTime.now(),
      ));

      expect(summary.fileCount, equals(2));
      expect(summary.totalLinesAdded, greaterThan(0));
    });

    test('diffsByDirectory groups files correctly', () {
      var summary = JobDiffSummary.empty('job-123');

      summary = summary.withDiff(FileDiff(
        filePath: 'lib/src/file1.dart',
        newContent: 'content',
        isNewFile: true,
        timestamp: DateTime.now(),
      ));

      summary = summary.withDiff(FileDiff(
        filePath: 'lib/src/file2.dart',
        newContent: 'content',
        isNewFile: true,
        timestamp: DateTime.now(),
      ));

      summary = summary.withDiff(FileDiff(
        filePath: 'test/test1.dart',
        newContent: 'content',
        isNewFile: true,
        timestamp: DateTime.now(),
      ));

      final byDir = summary.diffsByDirectory;
      expect(byDir['lib/src']?.length, equals(2));
      expect(byDir['test']?.length, equals(1));
    });
  });
}
