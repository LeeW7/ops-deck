import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
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

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _issueData;
  Map<String, dynamic>? _workflowState;
  bool _isLoading = true;
  bool _isProceeding = false;
  bool _isMerging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchIssueDetails();
  }

  Future<void> _fetchIssueDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch both issue details and workflow state in parallel
      final results = await Future.wait([
        _apiService.fetchIssueDetails(widget.repo, widget.issueNum),
        _apiService.fetchWorkflowState(widget.repo, widget.issueNum),
      ]);
      setState(() {
        _issueData = results[0];
        _workflowState = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _proceedToNextPhase() async {
    setState(() => _isProceeding = true);

    try {
      final result = await _apiService.proceedWithIssue(widget.repo, widget.issueNum);
      if (mounted) {
        final action = result['action'] as String? ?? 'next phase';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_capitalizeAction(action)} job queued!'),
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
      ),
      body: _buildBody(),
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
}
