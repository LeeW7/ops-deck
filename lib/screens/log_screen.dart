import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'issue_detail_screen.dart';

class LogScreen extends StatefulWidget {
  final Job job;

  const LogScreen({super.key, required this.job});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogProvider? _logProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logProvider = context.read<LogProvider>();
      _logProvider!.startPolling(widget.job.issueId);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (isAtBottom != _autoScroll) {
        setState(() {
          _autoScroll = isAtBottom;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _logProvider?.stopPolling();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Consumer<LogProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.logs.isEmpty) {
            return _buildLoadingView();
          }

          if (provider.error != null && provider.logs.isEmpty) {
            return _buildErrorView(provider.error!);
          }

          // Auto-scroll when new logs arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_autoScroll && _scrollController.hasClients) {
              _scrollToBottom();
            }
          });

          return _buildLogView(provider.logs);
        },
      ),
      floatingActionButton: Consumer<LogProvider>(
        builder: (context, provider, child) {
          if (!_autoScroll && provider.logs.isNotEmpty) {
            return FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _autoScroll = true;
                });
                _scrollToBottom();
              },
              backgroundColor: const Color(0xFF00FF41),
              child: const Icon(
                Icons.arrow_downward,
                color: Colors.black,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: widget.job.jobStatus == JobStatus.completed
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBottomBar() {
    // Determine button text and icon based on what command just completed
    String buttonText;
    IconData buttonIcon;

    final command = widget.job.command.toLowerCase();
    if (command.contains('plan')) {
      buttonText = 'VIEW PLAN & PROCEED';
      buttonIcon = Icons.description;
    } else if (command.contains('implement')) {
      buttonText = 'VIEW PR & NEXT STEPS';
      buttonIcon = Icons.merge_type;
    } else if (command.contains('retrospective')) {
      buttonText = 'VIEW RETROSPECTIVE';
      buttonIcon = Icons.psychology;
    } else {
      buttonText = 'VIEW ISSUE DETAILS';
      buttonIcon = Icons.article;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IssueDetailScreen(
                  repo: widget.job.repo,
                  issueNum: widget.job.issueNum,
                  issueTitle: widget.job.issueTitle,
                ),
              ),
            );
          },
          icon: Icon(buttonIcon),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          _buildStatusDot(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ISSUE #${widget.job.issueId}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.job.command,
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
        ],
      ),
      backgroundColor: const Color(0xFF161B22),
      foregroundColor: const Color(0xFF00FF41),
      elevation: 0,
      actions: [
        Consumer<LogProvider>(
          builder: (context, provider, child) {
            return IconButton(
              icon: const Icon(Icons.copy),
              onPressed: provider.logs.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: provider.logs));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Logs copied to clipboard',
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                          backgroundColor: const Color(0xFF238636),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              tooltip: 'Copy logs',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            context.read<LogProvider>().fetchLogs(widget.job.issueId);
          },
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildStatusDot() {
    Color color;
    switch (widget.job.jobStatus) {
      case JobStatus.running:
        color = const Color(0xFF3FB950);
        break;
      case JobStatus.failed:
        color = const Color(0xFFF85149);
        break;
      case JobStatus.completed:
        color = const Color(0xFF3FB950);
        break;
      default:
        color = const Color(0xFF8B949E);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'LOADING LOGS...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF8B949E),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFF85149),
            ),
            const SizedBox(height: 16),
            const Text(
              'FAILED TO LOAD LOGS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF85149),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF8B949E),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<LogProvider>().fetchLogs(widget.job.issueId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDA3633),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogView(String logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Color(0xFF8B949E),
            ),
            SizedBox(height: 16),
            Text(
              'NO LOGS YET',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFF8B949E),
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for output...',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      );
    }

    final lines = logs.split('\n');

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Scanline effect overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanlinePainter(),
              ),
            ),
          ),
          // Log content
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              return _buildLogLine(index + 1, lines[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogLine(int lineNumber, String content) {
    // Detect error keywords for highlighting
    final isError = content.toLowerCase().contains('error') ||
        content.toLowerCase().contains('fail') ||
        content.toLowerCase().contains('exception');
    final isWarning = content.toLowerCase().contains('warn');
    final isSuccess = content.toLowerCase().contains('success') ||
        content.toLowerCase().contains('complete');

    Color textColor;
    if (isError) {
      textColor = const Color(0xFFF85149);
    } else if (isWarning) {
      textColor = const Color(0xFFD29922);
    } else if (isSuccess) {
      textColor = const Color(0xFF3FB950);
    } else {
      textColor = const Color(0xFF00FF41);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              lineNumber.toString().padLeft(4),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: const Color(0xFF8B949E).withOpacity(0.5),
                height: 1.4,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: const Color(0xFF30363D),
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
