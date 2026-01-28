import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ops_deck/widgets/kanban/kanban_column.dart';
import 'package:ops_deck/widgets/kanban/done_column_header.dart';
import 'package:ops_deck/models/issue_model.dart';
import 'package:ops_deck/models/job_model.dart';

void main() {
  group('KanbanColumn header inline count', () {
    Issue createMockIssue(int issueNum) {
      return Issue(
        issueNum: issueNum,
        repo: 'test/repo',
        repoSlug: 'repo',
        title: 'Test Issue #$issueNum',
        jobs: [
          Job(
            issueId: 'job-$issueNum',
            status: 'running',
            command: 'test',
            startTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            repo: 'test/repo',
            repoSlug: 'repo',
            issueTitle: 'Test Issue #$issueNum',
            issueNum: issueNum,
            logPath: '/logs/job-$issueNum.log',
            localPath: '/local/repo',
            fullCommand: 'test command',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        currentPhase: WorkflowPhase.newIssue,
      );
    }

    testWidgets('displays inline count with 3 issues', (tester) async {
      final issues = [
        createMockIssue(1),
        createMockIssue(2),
        createMockIssue(3),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: KanbanColumn(
                status: IssueStatus.running,
                issues: issues,
              ),
            ),
          ),
        ),
      );

      // Find Text.rich widget containing the inline count format
      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text == 'RUNNING (3)';
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('displays inline count with 0 issues', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: KanbanColumn(
                status: IssueStatus.needsAction,
                issues: [],
              ),
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text == 'NEEDS ACTION (0)';
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('displays correct count for failed column', (tester) async {
      final issues = [createMockIssue(1)];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: KanbanColumn(
                status: IssueStatus.failed,
                issues: issues,
              ),
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text == 'FAILED (1)';
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });
  });

  group('DoneColumnHeader inline count', () {
    testWidgets('displays inline count with count 7', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: DoneColumnHeader(
              count: 7,
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text == 'DONE (7)';
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('displays inline count with count 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: DoneColumnHeader(
              count: 0,
            ),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text == 'DONE (0)';
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });
  });
}
