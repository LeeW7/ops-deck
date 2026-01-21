import 'package:flutter/material.dart';
import '../../models/issue_model.dart';

/// Collapsed header for the Done column that links to search
class DoneColumnHeader extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const DoneColumnHeader({
    super.key,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(IssueStatus.done.colorValue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF30363D),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Label
              Text(
                'DONE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              // Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              // Arrow indicating tap to view more
              Icon(
                Icons.search,
                size: 16,
                color: statusColor.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'View history',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: statusColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
