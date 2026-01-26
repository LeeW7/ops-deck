import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/session_model.dart';

/// Callback for session delete action
typedef SessionDeleteCallback = void Function(QuickSession session);

/// Card widget displaying a single QuickSession
class SessionCard extends StatefulWidget {
  final QuickSession session;
  final String? firstMessagePreview;
  final VoidCallback? onTap;
  final SessionDeleteCallback? onDelete;

  const SessionCard({
    super.key,
    required this.session,
    this.firstMessagePreview,
    this.onTap,
    this.onDelete,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _isLongPressActive = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.session.status);

    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isLongPressActive = true);
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        setState(() => _isLongPressActive = false);
        _showDeleteConfirmation(context);
      },
      onLongPressCancel: () {
        setState(() => _isLongPressActive = false);
      },
      child: AnimatedScale(
        scale: _isLongPressActive ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _isLongPressActive ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF30363D),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: repo + status
                    _buildHeader(context, statusColor),
                    const SizedBox(height: 8),
                    // Title/preview
                    _buildTitle(context),
                    const SizedBox(height: 8),
                    // Footer: message count + time + cost
                    _buildFooter(context, statusColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor) {
    return Row(
      children: [
        // Repo name badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF30363D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatRepoName(widget.session.repo),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF8B949E),
            ),
          ),
        ),
        const Spacer(),
        // Status indicator
        _buildStatusIndicator(statusColor),
      ],
    );
  }

  Widget _buildStatusIndicator(Color statusColor) {
    final status = widget.session.status;

    if (status == SessionStatus.running) {
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
            status.displayName,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: statusColor,
            ),
          ),
        ],
      );
    }

    IconData icon;
    switch (status) {
      case SessionStatus.idle:
        icon = Icons.pause_circle_outline;
        break;
      case SessionStatus.running:
        icon = Icons.play_circle_outline;
        break;
      case SessionStatus.failed:
        icon = Icons.error_outline;
        break;
      case SessionStatus.expired:
        icon = Icons.timer_off_outlined;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: statusColor),
        const SizedBox(width: 4),
        Text(
          status.displayName,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final preview = widget.firstMessagePreview;
    final displayText = preview != null && preview.isNotEmpty
        ? preview
        : 'Session ${widget.session.id.substring(0, 8)}...';

    return Text(
      displayText,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFFE6EDF3),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(BuildContext context, Color statusColor) {
    return Row(
      children: [
        // Message count
        const Icon(
          Icons.chat_bubble_outline,
          size: 12,
          color: Color(0xFF8B949E),
        ),
        const SizedBox(width: 4),
        Text(
          '${widget.session.messageCount}',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF8B949E),
          ),
        ),
        const SizedBox(width: 12),
        // Cost (if > 0)
        if (widget.session.totalCostUsd > 0) ...[
          const Icon(
            Icons.attach_money,
            size: 12,
            color: Color(0xFF8B949E),
          ),
          Text(
            widget.session.totalCostUsd.toStringAsFixed(4),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(width: 12),
        ],
        const Spacer(),
        // Time ago
        Text(
          _timeAgo(widget.session.lastActivity),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF8B949E),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.idle:
        return const Color(0xFF8B949E); // Muted gray
      case SessionStatus.running:
        return const Color(0xFF58A6FF); // Blue
      case SessionStatus.failed:
        return const Color(0xFFF85149); // Red
      case SessionStatus.expired:
        return const Color(0xFF6E7681); // Darker gray
    }
  }

  String _formatRepoName(String repo) {
    // Extract just the repo name if full path (e.g., "owner/repo" -> "repo")
    if (repo.contains('/')) {
      return repo.split('/').last;
    }
    return repo;
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

  void _showDeleteConfirmation(BuildContext context) {
    if (widget.onDelete == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text(
          'Delete Session',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFE6EDF3),
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this session? This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF8B949E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8B949E),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete!(widget.session);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFF85149),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
