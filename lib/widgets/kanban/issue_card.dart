import 'package:flutter/material.dart';
import '../../models/issue_model.dart';
import '../../models/job_model.dart';

/// Card representing an issue in the Kanban board
class IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;

  const IssueCard({
    super.key,
    required this.issue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = Color(issue.status.colorValue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF30363D),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: repo + issue number
              _buildHeader(context, statusColor),
              const SizedBox(height: 8),
              // Title
              Text(
                issue.title,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE6EDF3),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Footer: phase + time
              _buildFooter(context, statusColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor) {
    return Row(
      children: [
        // Repo name
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF30363D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            issue.repoSlug,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF8B949E),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Issue number
        Text(
          '#${issue.issueNum}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        const Spacer(),
        // Status indicator
        _buildStatusIndicator(statusColor),
      ],
    );
  }

  Widget _buildStatusIndicator(Color statusColor) {
    final runningJob = issue.runningJob;
    final failedJob = issue.failedJob;

    if (runningJob != null) {
      // Animated running indicator
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _commandDisplayName(runningJob.command),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: statusColor,
            ),
          ),
        ],
      );
    }

    if (failedJob != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            _commandDisplayName(failedJob.command),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: statusColor,
            ),
          ),
        ],
      );
    }

    // Show phase for needs action
    if (issue.status == IssueStatus.needsAction) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          issue.currentPhase.displayName,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      );
    }

    // Done state
    if (issue.status == IssueStatus.done) {
      return Icon(Icons.check_circle, size: 16, color: statusColor);
    }

    return const SizedBox.shrink();
  }

  Widget _buildFooter(BuildContext context, Color statusColor) {
    return Row(
      children: [
        // Workflow progress indicator
        _buildWorkflowProgress(statusColor),
        const Spacer(),
        // Time ago
        Text(
          _timeAgo(issue.lastActivityTime),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF8B949E),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowProgress(Color statusColor) {
    // Simple progress dots: plan -> implement -> review -> done
    final phases = ['plan', 'implement', 'retrospective'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < phases.length; i++) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: issue.completedPhases.contains(phases[i])
                  ? statusColor
                  : const Color(0xFF30363D),
              border: Border.all(
                color: statusColor.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          if (i < phases.length - 1)
            Container(
              width: 12,
              height: 2,
              color: issue.completedPhases.contains(phases[i])
                  ? statusColor.withOpacity(0.5)
                  : const Color(0xFF30363D),
            ),
        ],
      ],
    );
  }

  String _commandDisplayName(String command) {
    switch (command) {
      case 'plan-headless':
        return 'planning';
      case 'implement-headless':
        return 'implementing';
      case 'retrospective-headless':
        return 'retrospective';
      case 'revise-headless':
        return 'revising';
      default:
        return command.replaceAll('-headless', '');
    }
  }

  String _timeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
