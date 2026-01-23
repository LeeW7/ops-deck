import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'feedback_screen.dart';

class IssueDetailScreen extends StatefulWidget {
  final String repo;
  final int issueNum;
  final String? issueTitle;
  final String? issueId;

  const IssueDetailScreen({
    super.key,
    required this.repo,
    required this.issueNum,
    this.issueTitle,
    this.issueId,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _liveScrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<StreamMessage> _streamMessages = [];
  bool _isSendingInput = false;

  /// Process messages to combine consecutive text into paragraphs
  List<_ProcessedMessage> get _processedMessages {
    final result = <_ProcessedMessage>[];
    StringBuffer? textBuffer;

    for (final msg in _streamMessages) {
      if (msg.type == 'assistantText') {
        final text = (msg.data as TextData?)?.content ?? '';
        textBuffer ??= StringBuffer();
        textBuffer.write(text);
      } else {
        // Flush any accumulated text
        if (textBuffer != null && textBuffer.isNotEmpty) {
          result.add(_ProcessedMessage.text(textBuffer.toString()));
          textBuffer = null;
        }
        result.add(_ProcessedMessage.message(msg));
      }
    }

    // Flush remaining text
    if (textBuffer != null && textBuffer.isNotEmpty) {
      result.add(_ProcessedMessage.text(textBuffer.toString()));
    }

    return result;
  }

  Map<String, dynamic>? _issueData;
  Map<String, dynamic>? _workflowState;
  Map<String, dynamic>? _costData;
  bool _isLoading = true;
  bool _isLoadingCosts = false;
  bool _isProceeding = false;
  bool _isMerging = false;
  String? _error;
  String? _activeJobId;
  late TabController _tabController;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _wsStateSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchIssueDetails();
    _setupWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveScrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _wsSubscription?.cancel();
    _wsStateSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  /// Send user input to the running Claude process
  void _sendUserInput() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSendingInput) return;

    setState(() {
      _isSendingInput = true;
    });

    // Send via WebSocket
    _wsService.send({
      'type': 'user_input',
      'content': text,
    });

    // Add user message to stream for display
    setState(() {
      _streamMessages.add(StreamMessage(
        type: 'userInput',
        jobId: _activeJobId ?? '',
        timestamp: DateTime.now(),
        data: TextData(text),
      ));
      _inputController.clear();
      _isSendingInput = false;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_liveScrollController.hasClients) {
        _liveScrollController.animateTo(
          _liveScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setupWebSocket() {
    _wsSubscription = _wsService.messages.listen((message) {
      if (mounted) {
        setState(() {
          _streamMessages.add(message);
        });
        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_liveScrollController.hasClients) {
            _liveScrollController.animateTo(
              _liveScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });

        // When job completes, refresh everything
        if (message.type == 'result') {
          _refreshWorkflowState();
        }

        // Check for status message indicating completion
        final data = message.data;
        if (data is StatusData) {
          final status = data.status.toLowerCase();
          if (status == 'completed' || status == 'failed' || status == 'blocked') {
            // Refresh issue details from GitHub to show updated comments/plan
            _refreshIssueDetails();
          }
        }
      }
    });

    _wsStateSubscription = _wsService.connectionState.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _connectToActiveJob() {
    if (_activeJobId != null && !_wsService.isConnectedTo(_activeJobId!)) {
      _streamMessages.clear();
      _wsService.connect(_activeJobId!);
    }
  }

  Future<void> _fetchIssueDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch issue details from server (GitHub data) and workflow from server API in parallel
      final results = await Future.wait([
        _apiService.fetchIssueDetails(widget.repo, widget.issueNum),
        _apiService.fetchWorkflowState(widget.repo, widget.issueNum),
      ]);

      if (!mounted) return;

      setState(() {
        _issueData = results[0] as Map<String, dynamic>;
        _workflowState = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });

      // Check for active job to connect WebSocket
      _checkForActiveJob();

      // Fetch costs in background (don't block UI)
      _fetchCosts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _checkForActiveJob() {
    // Get the active job ID directly from the server workflow state
    final activeJobId = _workflowState?['active_job_id'] as String?;

    if (activeJobId != null && activeJobId.isNotEmpty) {
      if (_activeJobId != activeJobId) {
        _activeJobId = activeJobId;
        _streamMessages.clear();
        _connectToActiveJob();
      }
    } else {
      _activeJobId = null;
      _wsService.disconnect();
    }
  }

  /// Refresh workflow state after job completion - uses server API
  Future<void> _refreshWorkflowState() async {
    try {
      final workflow = await _apiService.fetchWorkflowState(widget.repo, widget.issueNum);
      if (mounted) {
        setState(() {
          _workflowState = workflow;
        });
        // Also refresh costs since job completed
        _fetchCosts();
        // Check if we need to connect to a new active job
        _checkForActiveJob();
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  /// Refresh issue details from GitHub (e.g., after plan is posted as comment)
  Future<void> _refreshIssueDetails() async {
    try {
      final issueData = await _apiService.fetchIssueDetails(widget.repo, widget.issueNum);
      if (mounted) {
        setState(() {
          _issueData = issueData;
        });
      }
      // Also refresh workflow state
      _refreshWorkflowState();
    } catch (e) {
      // Silently fail - not critical for background refresh
    }
  }

  Future<void> _fetchCosts() async {
    setState(() => _isLoadingCosts = true);

    try {
      // Use server API for costs
      final costs = await _apiService.fetchIssueCosts(widget.repo, widget.issueNum);
      if (mounted) {
        setState(() {
          _costData = costs;
          _isLoadingCosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCosts = false);
      }
    }
  }

  Future<void> _proceedToNextPhase() async {
    // Get the next action label from workflow state
    final nextActionLabel = _workflowState?['next_action_label'] as String?;
    if (nextActionLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No action available'),
          backgroundColor: Color(0xFFDA3633),
        ),
      );
      return;
    }

    // Extract command from label (e.g., "cmd:implement-headless" -> "implement-headless")
    final command = nextActionLabel.replaceFirst('cmd:', '');
    final nextAction = _workflowState?['next_action'] as String? ?? command;

    setState(() => _isProceeding = true);

    try {
      await _apiService.triggerJob(
        repo: widget.repo,
        issueNum: widget.issueNum,
        issueTitle: _displayTitle,
        command: command,
        cmdLabel: nextActionLabel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_capitalizeAction(nextAction)} job queued!'),
            backgroundColor: const Color(0xFF238636),
          ),
        );
        // Navigate back to home to see the new job
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProceeding = false);
    }
  }

  String _capitalizeAction(String action) {
    if (action.isEmpty) return action;
    return action[0].toUpperCase() + action.substring(1);
  }

  Future<void> _openPrUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _displayTitle =>
      widget.issueTitle ?? _issueData?['title'] as String? ?? 'Issue #${widget.issueNum}';

  Future<void> _navigateToFeedback() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackScreen(
          repo: widget.repo,
          issueNum: widget.issueNum,
          issueTitle: _displayTitle,
        ),
      ),
    );

    if (result == true && mounted) {
      // Feedback was submitted and revision job kicked off, go to home
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _showMergeConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text(
          'APPROVE & MERGE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: Color(0xFFE6EDF3),
            letterSpacing: 1,
          ),
        ),
        content: const Text(
          'This will squash merge the PR and close the issue. Are you sure you want to proceed?',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF8B949E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B949E),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'MERGE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _mergePr();
    }
  }

  Future<void> _mergePr() async {
    setState(() => _isMerging = true);

    try {
      final result = await _apiService.mergePr(widget.repo, widget.issueNum);
      if (mounted) {
        final prNum = result['pr_number'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PR #$prNum merged successfully!'),
            backgroundColor: const Color(0xFF238636),
          ),
        );
        // Navigate back to home
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'ISSUE #${widget.issueNum}',
          style: const TextStyle(
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
            icon: const Icon(Icons.refresh),
            onPressed: _fetchIssueDetails,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF41),
          labelColor: const Color(0xFF00FF41),
          unselectedLabelColor: const Color(0xFF8B949E),
          labelStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'DETAILS'),
            Tab(text: 'LIVE'),
            Tab(text: 'COSTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBody(),
          _buildLiveTab(),
          _buildCostsTab(),
        ],
      ),
      bottomNavigationBar: _issueData != null && !_isLoading
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Color(0xFFDA3633), size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFF85149),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchIssueDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final body = _issueData!['body'] as String? ?? '';
    final comments = _issueData!['comments'] as List<dynamic>? ?? [];
    final state = _issueData!['state'] as String? ?? 'UNKNOWN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and state
          Container(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state == 'OPEN'
                            ? const Color(0xFF238636)
                            : const Color(0xFF8957E5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.repo,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _displayTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Issue body
          if (body.isNotEmpty) ...[
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B949E),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: MarkdownBody(
                data: body,
                onTapLink: (text, href, title) => _openUrl(href),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFE6EDF3),
                    height: 1.5,
                  ),
                  a: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF58A6FF),
                    decoration: TextDecoration.underline,
                  ),
                  h1: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  h2: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  h3: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: const Color(0xFF00FF41),
                    backgroundColor: const Color(0xFF0D1117),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF00FF41),
                  ),
                  checkbox: const TextStyle(
                    color: Color(0xFF00FF41),
                  ),
                  tableHead: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  tableBody: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE6EDF3),
                  ),
                ),
              ),
            ),
          ],

          // Comments
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'COMMENTS (${comments.length})',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B949E),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...comments.map((comment) => _buildComment(comment)),
          ],

          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final author = comment['author']?['login'] as String? ?? 'Unknown';
    final body = comment['body'] as String? ?? '';
    final createdAt = comment['createdAt'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              const Icon(Icons.comment, size: 16, color: Color(0xFF8B949E)),
              const SizedBox(width: 8),
              Text(
                author,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF58A6FF),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: body,
            onTapLink: (text, href, title) => _openUrl(href),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFE6EDF3),
                height: 1.5,
              ),
              a: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF58A6FF),
                decoration: TextDecoration.underline,
              ),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: const Color(0xFF00FF41),
                backgroundColor: const Color(0xFF0D1117),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  Widget _buildLiveTab() {
    final connectionState = _wsService.state;
    final currentPhase = _workflowState?['current_phase'] as String? ?? 'new';
    final isActivePhase = ['planning', 'implementing', 'reviewing'].contains(currentPhase);

    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        children: [
          // Connection status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: Row(
              children: [
                _buildConnectionIndicator(connectionState),
                const SizedBox(width: 8),
                Text(
                  _getConnectionStatusText(connectionState, isActivePhase),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF8B949E),
                  ),
                ),
                const Spacer(),
                if (_activeJobId != null)
                  Text(
                    _activeJobId!.split('-').last.replaceAll('-headless', '').toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF58A6FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          // Terminal output
          Expanded(
            child: _streamMessages.isEmpty
                ? _buildEmptyLiveState(isActivePhase)
                : ListView.builder(
                    controller: _liveScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _processedMessages.length,
                    itemBuilder: (context, index) {
                      return _buildProcessedMessageWidget(_processedMessages[index]);
                    },
                  ),
          ),

          // Input bar (only show when job is active and connected)
          if (isActivePhase && connectionState == WsConnectionState.connected)
            _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFFC9D1D9),
              ),
              decoration: InputDecoration(
                hintText: 'Send a message to Claude...',
                hintStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFF6E7681),
                ),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
              onSubmitted: (_) => _sendUserInput(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _isSendingInput ? null : _sendUserInput,
            icon: _isSendingInput
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF58A6FF),
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF58A6FF),
                  ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(WsConnectionState state) {
    Color color;
    switch (state) {
      case WsConnectionState.connected:
        color = const Color(0xFF238636);
        break;
      case WsConnectionState.connecting:
        color = const Color(0xFFD29922);
        break;
      case WsConnectionState.error:
        color = const Color(0xFFDA3633);
        break;
      case WsConnectionState.disconnected:
        color = const Color(0xFF8B949E);
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getConnectionStatusText(WsConnectionState state, bool isActivePhase) {
    switch (state) {
      case WsConnectionState.connected:
        return 'Connected - streaming live';
      case WsConnectionState.connecting:
        return 'Connecting...';
      case WsConnectionState.error:
        return 'Connection error';
      case WsConnectionState.disconnected:
        return isActivePhase ? 'Disconnected' : 'No active job';
    }
  }

  Widget _buildEmptyLiveState(bool isActivePhase) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActivePhase ? Icons.hourglass_empty : Icons.terminal,
            size: 48,
            color: const Color(0xFF30363D),
          ),
          const SizedBox(height: 16),
          Text(
            isActivePhase ? 'Waiting for output...' : 'No active job',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
          if (!isActivePhase) ...[
            const SizedBox(height: 8),
            const Text(
              'Start a workflow phase to see live output',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF6E7681),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamMessageWidget(StreamMessage message) {
    switch (message.type) {
      case 'connected':
        return _buildSystemMessage('Connected to job stream', const Color(0xFF238636));

      case 'statusChange':
        final status = (message.data as StatusData?)?.status ?? 'unknown';
        return _buildSystemMessage('Status: $status', const Color(0xFF58A6FF));

      case 'assistantText':
        final text = (message.data as TextData?)?.content ?? '';
        return _buildTextMessage(text);

      case 'assistantThinking':
        return _buildThinkingMessage();

      case 'toolUse':
        final tool = (message.data as ToolData?)?.tool;
        return _buildToolUseMessage(tool);

      case 'toolResult':
        final tool = (message.data as ToolData?)?.tool;
        return _buildToolResultMessage(tool);

      case 'result':
        final result = (message.data as ResultDataWrapper?)?.result;
        return _buildResultMessage(result);

      case 'error':
        final error = (message.data as ErrorData?)?.error ?? 'Unknown error';
        return _buildSystemMessage('Error: $error', const Color(0xFFDA3633));

      case 'userInput':
        final text = (message.data as TextData?)?.content ?? '';
        return _buildUserInputMessage(text);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUserInputMessage(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F3A5F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF58A6FF).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.person_outline,
            size: 16,
            color: Color(0xFF58A6FF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFC9D1D9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '► $text',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextMessage(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFE6EDF3),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildThinkingMessage() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B949E)),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF8B949E),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolUseMessage(ToolUseData? tool) {
    if (tool == null) return const SizedBox.shrink();

    IconData icon;
    Color color;

    switch (tool.toolName.toLowerCase()) {
      case 'read':
        icon = Icons.description;
        color = const Color(0xFF58A6FF);
        break;
      case 'edit':
      case 'write':
        icon = Icons.edit;
        color = const Color(0xFFD29922);
        break;
      case 'bash':
        icon = Icons.terminal;
        color = const Color(0xFFA371F7);
        break;
      case 'glob':
      case 'grep':
        icon = Icons.search;
        color = const Color(0xFF3FB950);
        break;
      default:
        icon = Icons.build;
        color = const Color(0xFF8B949E);
    }

    // Check if this is an edit/write with content to show
    final editDetails = tool.editDetails;

    if (editDetails != null) {
      return _buildEditToolWidget(tool, editDetails, icon, color);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tool.displayText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditToolWidget(ToolUseData tool, EditDetails details, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 14, color: color),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  details.isWrite ? 'Write ${details.fileName}' : 'Edit ${details.fileName}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (details.linesAdded > 0)
                Text(
                  '+${details.linesAdded}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF3FB950),
                  ),
                ),
              if (details.linesRemoved > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '-${details.linesRemoved}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFFF85149),
                  ),
                ),
              ],
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show removed content (old)
                  if (details.oldContent != null && details.oldContent!.isNotEmpty) ...[
                    for (final line in details.oldContent!.split('\n').take(10))
                      Text(
                        '- $line',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFF85149),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (details.oldContent!.split('\n').length > 10)
                      Text(
                        '  ... ${details.oldContent!.split('\n').length - 10} more lines',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF6E7681),
                        ),
                      ),
                  ],
                  // Show added content (new)
                  if (details.newContent != null && details.newContent!.isNotEmpty) ...[
                    for (final line in details.newContent!.split('\n').take(10))
                      Text(
                        '+ $line',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF3FB950),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (details.newContent!.split('\n').length > 10)
                      Text(
                        '  ... ${details.newContent!.split('\n').length - 10} more lines',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF6E7681),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolResultMessage(ToolUseData? tool) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
      child: Text(
        '└─ done',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: const Color(0xFF3FB950).withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildResultMessage(ResultData? result) {
    if (result == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF238636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Color(0xFF238636)),
              SizedBox(width: 8),
              Text(
                'COMPLETE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF238636),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          if (result.totalCostUsd != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cost: \$${result.totalCostUsd!.toStringAsFixed(4)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF00FF41),
              ),
            ),
          ],
          if (result.inputTokens != null && result.outputTokens != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tokens: ${_formatTokenCount(result.inputTokens!)} in / ${_formatTokenCount(result.outputTokens!)} out',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFF8B949E),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostsTab() {
    if (_isLoadingCosts) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
        ),
      );
    }

    if (_costData == null) {
      return const Center(
        child: Text(
          'No cost data available',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF8B949E),
          ),
        ),
      );
    }

    final phases = (_costData!['phases'] as List<dynamic>?) ?? [];
    final totalCost = (_costData!['total_cost'] as num?)?.toDouble() ?? 0.0;
    final totalInputTokens = _costData!['total_input_tokens'] as int? ?? 0;
    final totalOutputTokens = _costData!['total_output_tokens'] as int? ?? 0;
    final totalCacheRead = _costData!['total_cache_read_tokens'] as int? ?? 0;
    final totalCacheWrite = _costData!['total_cache_write_tokens'] as int? ?? 0;

    if (phases.isEmpty) {
      return const Center(
        child: Text(
          'No completed jobs yet',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF8B949E),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total cost summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF238636)),
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL COST',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B949E),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${totalCost.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00FF41),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTokenStat('INPUT', totalInputTokens),
                    _buildTokenStat('OUTPUT', totalOutputTokens),
                    _buildTokenStat('CACHE R', totalCacheRead),
                    _buildTokenStat('CACHE W', totalCacheWrite),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Phase breakdown header
          const Text(
            'COST BY PHASE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          // Phase cards
          ...phases.map((phase) => _buildPhaseCard(phase)),

          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildTokenStat(String label, int count) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF8B949E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTokenCount(count),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE6EDF3),
          ),
        ),
      ],
    );
  }

  String _formatTokenCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildPhaseCard(Map<String, dynamic> phase) {
    final phaseName = phase['phase'] as String? ?? 'Unknown';
    final cost = (phase['cost'] as num?)?.toDouble() ?? 0.0;
    final inputTokens = phase['input_tokens'] as int? ?? 0;
    final outputTokens = phase['output_tokens'] as int? ?? 0;
    final model = phase['model'] as String? ?? 'unknown';
    final runCount = phase['run_count'] as int? ?? 1;

    // Calculate percentage of total
    final totalCost = (_costData!['total_cost'] as num?)?.toDouble() ?? 1.0;
    final percentage = totalCost > 0 ? (cost / totalCost * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    phaseName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                  if (runCount > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30363D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '×$runCount',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '\$${cost.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar showing percentage of total
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: const Color(0xFF30363D),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF238636)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% of total',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
              Text(
                '${_formatTokenCount(inputTokens)} in / ${_formatTokenCount(outputTokens)} out',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF6E7681),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final currentPhase = _workflowState?['current_phase'] as String? ?? 'new';
    final nextAction = _workflowState?['next_action'] as String?;
    final prUrl = _workflowState?['pr_url'] as String?;
    final completedPhases = (_workflowState?['completed_phases'] as List<dynamic>?) ?? [];
    final revisionCount = _workflowState?['revision_count'] as int? ?? 0;
    final canRevise = _workflowState?['can_revise'] as bool? ?? false;
    final canMerge = _workflowState?['can_merge'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Workflow progress indicator with revision count
            _buildWorkflowProgress(completedPhases, currentPhase, revisionCount),
            const SizedBox(height: 12),

            // PR link if available (for review phase)
            if (prUrl != null && currentPhase == 'review') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openPrUrl(prUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('OPEN PULL REQUEST'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF58A6FF),
                    side: const BorderSide(color: Color(0xFF58A6FF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Plan complete phase - allow requesting plan changes
            if (currentPhase == 'plan_complete' && canRevise) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _navigateToFeedback,
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('REQUEST PLAN CHANGES'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA371F7),
                    side: const BorderSide(color: Color(0xFFA371F7)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Review phase buttons (Request Changes and Approve & Merge)
            if (currentPhase == 'review') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canRevise ? _navigateToFeedback : null,
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text('REQUEST CHANGES'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDA3633),
                        side: BorderSide(
                          color: canRevise ? const Color(0xFFDA3633) : const Color(0xFF30363D),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canMerge && !_isMerging ? _showMergeConfirmation : null,
                      icon: _isMerging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(_isMerging ? 'MERGING...' : 'APPROVE & MERGE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF238636).withOpacity(0.5),
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('BACK'),
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
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildActionButton(currentPhase, nextAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowProgress(List<dynamic> completedPhases, String currentPhase, [int revisionCount = 0]) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPhaseIndicator('PLAN', completedPhases.contains('plan'), currentPhase == 'planning'),
            _buildPhaseDivider(completedPhases.contains('plan')),
            _buildPhaseIndicator('IMPLEMENT', completedPhases.contains('implement'), currentPhase == 'implementing'),
            _buildPhaseDivider(completedPhases.contains('implement')),
            _buildPhaseIndicator('REVIEW', currentPhase == 'complete' || completedPhases.contains('retrospective'), currentPhase == 'review'),
            _buildPhaseDivider(completedPhases.contains('retrospective')),
            _buildPhaseIndicator('RETRO', completedPhases.contains('retrospective'), false),
          ],
        ),
        if (revisionCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Revisions: $revisionCount',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF8B949E),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhaseIndicator(String label, bool completed, bool active) {
    Color bgColor;
    Color textColor;

    if (completed) {
      bgColor = const Color(0xFF238636);
      textColor = Colors.white;
    } else if (active) {
      bgColor = const Color(0xFF1F6FEB);
      textColor = Colors.white;
    } else {
      bgColor = const Color(0xFF30363D);
      textColor = const Color(0xFF8B949E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildPhaseDivider(bool completed) {
    return Container(
      width: 16,
      height: 2,
      color: completed ? const Color(0xFF238636) : const Color(0xFF30363D),
    );
  }

  Widget _buildActionButton(String currentPhase, String? nextAction) {
    // No action available
    if (nextAction == null) {
      if (currentPhase == 'complete') {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle),
          label: const Text('WORKFLOW COMPLETE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF238636).withOpacity(0.5),
            disabledForegroundColor: Colors.white.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      // In progress or waiting
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
        label: const Text('IN PROGRESS...'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF30363D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF30363D),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Determine button text based on next action
    String buttonText;
    IconData buttonIcon;
    switch (nextAction) {
      case 'plan':
        buttonText = 'START PLANNING';
        buttonIcon = Icons.edit_note;
        break;
      case 'implement':
        buttonText = 'PROCEED TO IMPLEMENT';
        buttonIcon = Icons.play_arrow;
        break;
      case 'retrospective':
        buttonText = 'RUN RETROSPECTIVE';
        buttonIcon = Icons.psychology;
        break;
      default:
        buttonText = 'PROCEED';
        buttonIcon = Icons.arrow_forward;
    }

    return ElevatedButton.icon(
      onPressed: _isProceeding ? null : _proceedToNextPhase,
      icon: _isProceeding
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(buttonIcon),
      label: Text(_isProceeding ? 'QUEUING...' : buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProcessedMessageWidget(_ProcessedMessage processed) {
    if (processed.isText) {
      return _buildTextMessage(processed.text!);
    } else {
      return _buildStreamMessageWidget(processed.message!);
    }
  }
}

/// Helper class for processed messages (combined text or single message)
class _ProcessedMessage {
  final String? text;
  final StreamMessage? message;

  _ProcessedMessage.text(this.text) : message = null;
  _ProcessedMessage.message(this.message) : text = null;

  bool get isText => text != null;
}
