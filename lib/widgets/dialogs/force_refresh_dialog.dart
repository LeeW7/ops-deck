import 'package:flutter/material.dart';

/// Confirmation dialog for force refreshing all cached data.
/// Explains that this will clear cache and fetch fresh data from server.
class ForceRefreshDialog extends StatelessWidget {
  const ForceRefreshDialog({super.key});

  /// Show the dialog and return true if confirmed, false otherwise
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ForceRefreshDialog(),
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
          Icon(Icons.refresh, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Text(
            'Force Refresh?',
            style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 16),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will clear all cached data and fetch fresh status from the server.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          SizedBox(height: 12),
          Text(
            'Use this if jobs appear stuck or if you suspect stale data.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
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
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Force Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }
}
