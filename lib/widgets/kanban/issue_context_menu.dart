import 'package:flutter/material.dart';
import '../../models/issue_model.dart';

/// Context menu for issue cards with actions like view details, open in GitHub,
/// remove from board, and close issue.
class IssueContextMenu extends StatelessWidget {
  final Issue issue;
  final VoidCallback onViewDetails;
  final VoidCallback onOpenInGitHub;
  final VoidCallback onRemoveFromBoard;
  final VoidCallback onCloseIssue;
  final VoidCallback onDismiss;

  const IssueContextMenu({
    super.key,
    required this.issue,
    required this.onViewDetails,
    required this.onOpenInGitHub,
    required this.onRemoveFromBoard,
    required this.onCloseIssue,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: Icons.open_in_new,
              label: 'View Details',
              onTap: onViewDetails,
            ),
            _buildMenuItem(
              icon: Icons.link,
              label: 'Open in GitHub',
              onTap: onOpenInGitHub,
            ),
            const Divider(color: Color(0xFF30363D), height: 1),
            _buildMenuItem(
              icon: Icons.visibility_off_outlined,
              label: 'Remove from Board',
              onTap: onRemoveFromBoard,
            ),
            _buildMenuItem(
              icon: Icons.close,
              label: 'Close Issue',
              onTap: onCloseIssue,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? const Color(0xFFDA3633) : const Color(0xFFE6EDF3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the context menu as an overlay
Future<void> showIssueContextMenu({
  required BuildContext context,
  required Issue issue,
  required Offset position,
  required VoidCallback onViewDetails,
  required VoidCallback onOpenInGitHub,
  required VoidCallback onRemoveFromBoard,
  required VoidCallback onCloseIssue,
}) async {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  void removeOverlay() {
    overlayEntry.remove();
  }

  overlayEntry = OverlayEntry(
    builder: (context) {
      // Calculate position to keep menu on screen
      final screenSize = MediaQuery.of(context).size;
      const menuWidth = 200.0;
      const menuHeight = 200.0;

      double left = position.dx;
      double top = position.dy;

      // Adjust horizontal position
      if (left + menuWidth > screenSize.width - 16) {
        left = screenSize.width - menuWidth - 16;
      }
      if (left < 16) {
        left = 16;
      }

      // Adjust vertical position
      if (top + menuHeight > screenSize.height - 16) {
        top = position.dy - menuHeight;
      }
      if (top < 16) {
        top = 16;
      }

      return Stack(
        children: [
          // Tap barrier to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu
          Positioned(
            left: left,
            top: top,
            child: IssueContextMenu(
              issue: issue,
              onViewDetails: () {
                removeOverlay();
                onViewDetails();
              },
              onOpenInGitHub: () {
                removeOverlay();
                onOpenInGitHub();
              },
              onRemoveFromBoard: () {
                removeOverlay();
                onRemoveFromBoard();
              },
              onCloseIssue: () {
                removeOverlay();
                onCloseIssue();
              },
              onDismiss: removeOverlay,
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(overlayEntry);
}
