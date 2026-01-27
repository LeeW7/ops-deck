import 'package:flutter/material.dart';
import '../models/file_diff_model.dart';
import '../widgets/diff/diff_viewer.dart';

/// Full-screen diff review before approving changes
class DiffReviewScreen extends StatefulWidget {
  final JobDiffSummary summary;
  final String issueTitle;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const DiffReviewScreen({
    super.key,
    required this.summary,
    required this.issueTitle,
    this.onApprove,
    this.onReject,
  });

  @override
  State<DiffReviewScreen> createState() => _DiffReviewScreenState();
}

class _DiffReviewScreenState extends State<DiffReviewScreen> {
  int _selectedFileIndex = 0;
  bool _showFullDiff = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'REVIEW CHANGES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: const Color(0xFF00FF41),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showFullDiff ? Icons.unfold_less : Icons.unfold_more,
            ),
            onPressed: () {
              setState(() {
                _showFullDiff = !_showFullDiff;
              });
            },
            tooltip: _showFullDiff ? 'Collapse all' : 'Expand all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          _buildSummaryHeader(),
          // File list and diff viewer
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.issueTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      size: 14,
                      color: Color(0xFF8B949E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.summary.fileCount} ${widget.summary.fileCount == 1 ? 'file' : 'files'}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '+${widget.summary.totalLinesAdded}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3FB950),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-${widget.summary.totalLinesRemoved}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF85149),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.summary.diffs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Color(0xFF30363D),
            ),
            SizedBox(height: 16),
            Text(
              'No changes to review',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // File list sidebar
        Container(
          width: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            border: Border(
              right: BorderSide(color: Color(0xFF30363D)),
            ),
          ),
          child: _buildFileList(),
        ),
        // Diff viewer
        Expanded(
          child: _buildDiffViewer(),
        ),
      ],
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      itemCount: widget.summary.diffs.length,
      itemBuilder: (context, index) {
        final diff = widget.summary.diffs[index];
        final isSelected = index == _selectedFileIndex;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedFileIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1F6FEB).withOpacity(0.2)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected
                      ? const Color(0xFF58A6FF)
                      : Colors.transparent,
                  width: 3,
                ),
                bottom: const BorderSide(
                  color: Color(0xFF30363D),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildFileIcon(diff),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diff.fileName,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFE6EDF3)
                              : const Color(0xFF8B949E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (diff.linesAdded > 0)
                            Text(
                              '+${diff.linesAdded}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF3FB950),
                              ),
                            ),
                          if (diff.linesRemoved > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '-${diff.linesRemoved}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFFF85149),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileIcon(FileDiff diff) {
    Color color;
    IconData icon;

    if (diff.isNewFile) {
      color = const Color(0xFF3FB950);
      icon = Icons.add_circle_outline;
    } else {
      color = const Color(0xFFD29922);
      icon = Icons.edit_outlined;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildDiffViewer() {
    if (_selectedFileIndex >= widget.summary.diffs.length) {
      return const SizedBox.shrink();
    }

    final diff = widget.summary.diffs[_selectedFileIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DiffViewer(
        diff: diff,
        expanded: _showFullDiff,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('CLOSE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B949E),
                  side: const BorderSide(color: Color(0xFF30363D)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (widget.onReject != null || widget.onApprove != null) ...[
              const SizedBox(width: 12),
              if (widget.onReject != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onReject?.call();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDA3633),
                      side: const BorderSide(color: Color(0xFFDA3633)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (widget.onApprove != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApprove?.call();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('APPROVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Mobile-friendly version with bottom sheet for file selection
class MobileDiffReviewScreen extends StatefulWidget {
  final JobDiffSummary summary;
  final String issueTitle;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const MobileDiffReviewScreen({
    super.key,
    required this.summary,
    required this.issueTitle,
    this.onApprove,
    this.onReject,
  });

  @override
  State<MobileDiffReviewScreen> createState() => _MobileDiffReviewScreenState();
}

class _MobileDiffReviewScreenState extends State<MobileDiffReviewScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'REVIEW CHANGES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: const Color(0xFF00FF41),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary header
          _buildSummaryHeader(),
          // File navigation
          if (widget.summary.diffs.isNotEmpty) _buildFileNavigation(),
          // Diff content
          Expanded(
            child: widget.summary.diffs.isEmpty
                ? _buildEmptyState()
                : PageView.builder(
                    controller: _pageController,
                    itemCount: widget.summary.diffs.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DiffViewer(
                          diff: widget.summary.diffs[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.issueTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${widget.summary.fileCount} files',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '+${widget.summary.totalLinesAdded}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3FB950),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '-${widget.summary.totalLinesRemoved}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF85149),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileNavigation() {
    final diff = widget.summary.diffs[_currentIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: const Color(0xFF58A6FF),
            disabledColor: const Color(0xFF30363D),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  diff.fileName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${_currentIndex + 1} of ${widget.summary.diffs.length}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _currentIndex < widget.summary.diffs.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: const Color(0xFF58A6FF),
            disabledColor: const Color(0xFF30363D),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Color(0xFF30363D),
          ),
          SizedBox(height: 16),
          Text(
            'No changes to review',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B949E),
                  side: const BorderSide(color: Color(0xFF30363D)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('CLOSE'),
              ),
            ),
            if (widget.onApprove != null) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApprove?.call();
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
