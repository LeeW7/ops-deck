import 'package:flutter/material.dart';
import '../../models/issue_model.dart';
import 'issue_card.dart';

/// A single column in the Kanban board
class KanbanColumn extends StatelessWidget {
  final IssueStatus status;
  final List<Issue> issues;
  final void Function(Issue)? onIssueTap;
  final IssueContextMenuCallback? onIssueContextMenu;
  final bool collapsed;
  final VoidCallback? onCollapsedTap;

  const KanbanColumn({
    super.key,
    required this.status,
    required this.issues,
    this.onIssueTap,
    this.onIssueContextMenu,
    this.collapsed = false,
    this.onCollapsedTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = Color(status.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF30363D),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header
          _buildHeader(context, statusColor),
          // Cards or collapsed content
          if (!collapsed)
            Expanded(
              child: issues.isEmpty
                  ? _buildEmptyState(context)
                  : _buildCardList(context),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor) {
    return GestureDetector(
      onTap: collapsed ? onCollapsedTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          border: Border(
            bottom: BorderSide(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Status name
            Text(
              status.displayName,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: statusColor,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${issues.length}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _emptyIcon,
              size: 32,
              color: const Color(0xFF8B949E).withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              _emptyMessage,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: const Color(0xFF8B949E).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _emptyIcon {
    switch (status) {
      case IssueStatus.needsAction:
        return Icons.inbox_outlined;
      case IssueStatus.running:
        return Icons.play_circle_outline;
      case IssueStatus.failed:
        return Icons.check_circle_outline;
      case IssueStatus.done:
        return Icons.celebration_outlined;
    }
  }

  String get _emptyMessage {
    switch (status) {
      case IssueStatus.needsAction:
        return 'No issues waiting';
      case IssueStatus.running:
        return 'No active jobs';
      case IssueStatus.failed:
        return 'No failures';
      case IssueStatus.done:
        return 'No completed issues';
    }
  }

  Widget _buildCardList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IssueCard(
            issue: issue,
            onTap: onIssueTap != null ? () => onIssueTap!(issue) : null,
            onContextMenu: onIssueContextMenu,
          ),
        );
      },
    );
  }
}
