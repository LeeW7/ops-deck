import 'package:flutter/material.dart';

/// Empty state widget shown when no sessions exist
class EmptySessionsState extends StatelessWidget {
  final VoidCallback? onCreateSession;

  const EmptySessionsState({
    super.key,
    this.onCreateSession,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF30363D),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: Color(0xFF8B949E),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              'No sessions yet',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6EDF3),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            const Text(
              'Start a conversation with Claude',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFF8B949E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // CTA Button
            if (onCreateSession != null)
              _buildCreateButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCreateSession,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF238636),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2EA043),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 18,
                color: Color(0xFFFFFFFF),
              ),
              SizedBox(width: 8),
              Text(
                'New Session',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
