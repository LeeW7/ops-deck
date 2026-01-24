import 'package:flutter/material.dart';
import '../../models/issue_model.dart';

/// Confirmation dialog for removing an issue from the board (local hide).
/// Shows issue preview and explains the action can be undone.
class RemoveConfirmationDialog extends StatelessWidget {
  final Issue issue;

  const RemoveConfirmationDialog({super.key, required this.issue});

  /// Show the dialog and return true if confirmed, false otherwise
  static Future<bool> show(BuildContext context, Issue issue) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RemoveConfirmationDialog(issue: issue),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      title: const Row(
        children: [
          Icon(Icons.visibility_off_outlined, color: Color(0xFF8B949E)),
          SizedBox(width: 8),
          Text(
            'Remove from Board',
            style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hide this issue from your Kanban board? You can trigger a new job to restore it.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildIssuePreview(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
          ),
          child: const Text('Remove'),
        ),
      ],
    );
  }

  Widget _buildIssuePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  issue.repoSlug,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8B949E),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${issue.issueNum}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF0883E),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE6EDF3),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
