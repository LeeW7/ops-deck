import 'package:flutter/material.dart';
import '../../models/file_diff_model.dart';

/// Widget to display a unified diff for a single file
class DiffViewer extends StatelessWidget {
  final FileDiff diff;
  final bool expanded;

  const DiffViewer({
    super.key,
    required this.diff,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final lines = diff.unifiedDiff;

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No changes to display',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF8B949E),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File header
          _buildFileHeader(),
          // Diff lines
          if (expanded) _buildDiffContent(lines),
        ],
      ),
    );
  }

  Widget _buildFileHeader() {
    final IconData icon;
    final Color iconColor;

    if (diff.isNewFile) {
      icon = Icons.add_circle;
      iconColor = const Color(0xFF3FB950);
    } else if (diff.linesAdded > 0 && diff.linesRemoved > 0) {
      icon = Icons.edit;
      iconColor = const Color(0xFFD29922);
    } else if (diff.linesAdded > 0) {
      icon = Icons.add;
      iconColor = const Color(0xFF3FB950);
    } else {
      icon = Icons.remove;
      iconColor = const Color(0xFFF85149);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              diff.filePath,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6EDF3),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildChangeBadge(),
        ],
      ),
    );
  }

  Widget _buildChangeBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (diff.linesAdded > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF238636).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${diff.linesAdded}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3FB950),
              ),
            ),
          ),
        if (diff.linesRemoved > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDA3633).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${diff.linesRemoved}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF85149),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiffContent(List<DiffLine> lines) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        return _buildDiffLine(line, index);
      },
    );
  }

  Widget _buildDiffLine(DiffLine line, int index) {
    Color bgColor;
    Color textColor;
    String prefix;

    switch (line.type) {
      case DiffLineType.added:
        bgColor = const Color(0xFF238636).withOpacity(0.15);
        textColor = const Color(0xFF3FB950);
        prefix = '+';
        break;
      case DiffLineType.removed:
        bgColor = const Color(0xFFDA3633).withOpacity(0.15);
        textColor = const Color(0xFFF85149);
        prefix = '-';
        break;
      case DiffLineType.unchanged:
        bgColor = Colors.transparent;
        textColor = const Color(0xFF8B949E);
        prefix = ' ';
        break;
      case DiffLineType.context:
        bgColor = const Color(0xFF1F6FEB).withOpacity(0.1);
        textColor = const Color(0xFF58A6FF);
        prefix = '@';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Text(
              prefix,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact diff viewer that shows only a summary
class CompactDiffViewer extends StatelessWidget {
  final FileDiff diff;
  final VoidCallback? onTap;

  const CompactDiffViewer({
    super.key,
    required this.diff,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          children: [
            _buildFileIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diff.fileName,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getDirectoryPath(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF8B949E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildChangeStats(),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF8B949E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    final extension = diff.extension.toLowerCase();
    IconData icon;
    Color color;

    switch (extension) {
      case 'dart':
        icon = Icons.flutter_dash;
        color = const Color(0xFF58A6FF);
        break;
      case 'swift':
        icon = Icons.apple;
        color = const Color(0xFFFA7343);
        break;
      case 'kt':
      case 'java':
        icon = Icons.android;
        color = const Color(0xFF3DDC84);
        break;
      case 'json':
      case 'yaml':
      case 'yml':
        icon = Icons.data_object;
        color = const Color(0xFFD29922);
        break;
      case 'md':
        icon = Icons.article;
        color = const Color(0xFF8B949E);
        break;
      default:
        icon = Icons.insert_drive_file;
        color = const Color(0xFF8B949E);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  String _getDirectoryPath() {
    final parts = diff.filePath.split('/');
    if (parts.length <= 1) return '/';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  Widget _buildChangeStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (diff.linesAdded > 0)
          Text(
            '+${diff.linesAdded}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3FB950),
            ),
          ),
        if (diff.linesRemoved > 0) ...[
          const SizedBox(width: 6),
          Text(
            '-${diff.linesRemoved}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF85149),
            ),
          ),
        ],
      ],
    );
  }
}
