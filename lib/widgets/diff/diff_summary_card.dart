import 'package:flutter/material.dart';
import '../../models/file_diff_model.dart';

/// Card showing a summary of all changes in a job
class DiffSummaryCard extends StatelessWidget {
  final JobDiffSummary summary;
  final VoidCallback? onTap;

  const DiffSummaryCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.diffs.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6FEB).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.difference,
                    size: 20,
                    color: Color(0xFF58A6FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENDING CHANGES',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B949E),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.fileCount} ${summary.fileCount == 1 ? 'file' : 'files'} changed',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE6EDF3),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStats(),
              ],
            ),
            const SizedBox(height: 12),
            // File list preview
            _buildFilePreview(),
            const SizedBox(height: 12),
            // Tap to review
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.touch_app,
                  size: 14,
                  color: Color(0xFF58A6FF),
                ),
                const SizedBox(width: 6),
                const Text(
                  'TAP TO REVIEW CHANGES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF58A6FF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.totalLinesAdded > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF238636).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${summary.totalLinesAdded}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3FB950),
              ),
            ),
          ),
        if (summary.totalLinesRemoved > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDA3633).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${summary.totalLinesRemoved}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF85149),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePreview() {
    // Show first 3 files
    final previewDiffs = summary.diffs.take(3).toList();
    final remainingCount = summary.diffs.length - 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...previewDiffs.map((diff) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                diff.isNewFile ? Icons.add_circle_outline : Icons.edit_outlined,
                size: 14,
                color: diff.isNewFile
                    ? const Color(0xFF3FB950)
                    : const Color(0xFFD29922),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diff.fileName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE6EDF3),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '+${diff.linesAdded}/-${diff.linesRemoved}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        )),
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '... and $remainingCount more ${remainingCount == 1 ? 'file' : 'files'}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFF8B949E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Inline banner to show when reviewing changes is recommended
class ReviewChangesBanner extends StatelessWidget {
  final int fileCount;
  final int linesAdded;
  final int linesRemoved;
  final VoidCallback onReview;

  const ReviewChangesBanner({
    super.key,
    required this.fileCount,
    required this.linesAdded,
    required this.linesRemoved,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F6FEB).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F6FEB).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.difference,
            size: 20,
            color: Color(0xFF58A6FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fileCount ${fileCount == 1 ? 'file' : 'files'} modified',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                ),
                Text(
                  '+$linesAdded / -$linesRemoved lines',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('REVIEW'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF58A6FF),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
