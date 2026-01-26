import 'package:flutter/material.dart';
import '../../models/issue_model.dart';

/// Confirmation dialog for closing an issue on GitHub.
/// Shows warning that this action cannot be undone from the app.
class CloseIssueDialog extends StatelessWidget {
  final Issue issue;

  const CloseIssueDialog({super.key, required this.issue});

  /// Show the dialog and return true if confirmed, false otherwise
  static Future<bool> show(BuildContext context, Issue issue) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CloseIssueDialog(issue: issue),
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
          Icon(Icons.close, color: Color(0xFFDA3633)),
          SizedBox(width: 8),
          Text(
            'Close Issue',
            style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Close this issue on GitHub? The issue will be marked as closed and removed from your board.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildIssuePreview(),
          const SizedBox(height: 12),
          _buildWarningBox(),
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
            backgroundColor: const Color(0xFFDA3633),
            foregroundColor: Colors.white,
          ),
          child: const Text('Close Issue'),
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

  Widget _buildWarningBox() {
    // Pre-computed colors to avoid deprecated withOpacity
    const warningBgColor = Color(0x1ADA3633); // 0xFFDA3633 at 10% opacity
    const warningBorderColor = Color(0x4DDA3633); // 0xFFDA3633 at 30% opacity

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warningBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warningBorderColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Color(0xFFDA3633), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This action cannot be undone from the app. You can reopen the issue from GitHub.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B949E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
