import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/issue_model.dart';
import '../providers/issue_board_provider.dart';
import '../widgets/kanban/kanban_column.dart';
import '../widgets/kanban/repo_filter_chips.dart';
import '../widgets/kanban/done_column_header.dart';
import '../widgets/kanban/issue_context_menu.dart';
import '../widgets/dialogs/remove_confirmation_dialog.dart';
import '../widgets/dialogs/close_issue_dialog.dart';
import 'issue_detail_screen.dart';
import 'issue_search_screen.dart';
import 'create_issue_screen.dart';
import 'settings_screen.dart';
import 'quick_tasks_screen.dart';

/// Main Kanban board screen displaying issues grouped by status
class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // The columns to display (excluding Done which is collapsed)
  static const _columnStatuses = [
    IssueStatus.needsAction,
    IssueStatus.running,
    IssueStatus.failed,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndStartPolling();
    });
  }

  void _initializeAndStartPolling() {
    final provider = context.read<IssueBoardProvider>();
    provider.stopRealTimeUpdates(); // Stop any existing updates first
    provider.initialize().then((_) {
      if (provider.isConfigured) {
        provider.startRealTimeUpdates();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    context.read<IssueBoardProvider>().stopRealTimeUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<IssueBoardProvider>(
        builder: (context, provider, _) {
          if (!provider.isConfigured) {
            return _buildNotConfigured(context);
          }

          if (provider.isLoading && provider.issues.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.issues.isEmpty) {
            return _buildError(context, provider.error!);
          }

          return _buildBoard(context, provider);
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('claude-ops'),
      actions: [
        // Quick Tasks button
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Quick Tasks',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickTasksScreen()),
            );
          },
        ),
        // Search button
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search issues',
          onPressed: () => _openSearch(context),
        ),
        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            // Re-initialize after returning from settings (re-checks Firestore)
            if (mounted) {
              _initializeAndStartPolling();
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Consumer<IssueBoardProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                RepoFilterChips(
                  repos: provider.availableRepos,
                  selectedRepos: provider.selectedRepos,
                  onToggle: provider.toggleRepoFilter,
                  onClearAll: provider.clearRepoFilters,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotConfigured(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings_outlined,
              size: 64,
              color: Color(0xFF8B949E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Server not configured',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6EDF3),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure the server URL in settings to start monitoring your issues.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF8B949E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF8B949E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<IssueBoardProvider>().fetchJobs(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context, IssueBoardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return _buildMobileBoard(context, provider);
        } else {
          return _buildDesktopBoard(context, provider);
        }
      },
    );
  }

  Widget _buildMobileBoard(BuildContext context, IssueBoardProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.fetchJobs(),
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                // Done column header (collapsed, links to search)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: DoneColumnHeader(
                    count: provider.doneIssues.length,
                    onTap: () => _openSearch(context, initialStatus: IssueStatus.done),
                  ),
                ),
                // Swipeable columns
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemCount: _columnStatuses.length,
                    itemBuilder: (context, index) {
                      final status = _columnStatuses[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 16, left: 4),
                        child: KanbanColumn(
                          status: status,
                          issues: provider.issuesForStatus(status),
                          onIssueTap: (issue) => _openIssueDetail(context, issue),
                          onIssueContextMenu: (issue, position) => _handleIssueContextMenu(context, issue, position),
                        ),
                      );
                    },
                  ),
                ),
                // Page indicator
                _buildPageIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBoard(BuildContext context, IssueBoardProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.fetchJobs(),
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Done column header
                  DoneColumnHeader(
                    count: provider.doneIssues.length,
                    onTap: () => _openSearch(context, initialStatus: IssueStatus.done),
                  ),
                  const SizedBox(height: 16),
                  // Main columns in a row
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < _columnStatuses.length; i++) ...[
                          Expanded(
                            child: KanbanColumn(
                              status: _columnStatuses[i],
                              issues: provider.issuesForStatus(_columnStatuses[i]),
                              onIssueTap: (issue) => _openIssueDetail(context, issue),
                              onIssueContextMenu: (issue, position) => _handleIssueContextMenu(context, issue, position),
                            ),
                          ),
                          if (i < _columnStatuses.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _columnStatuses.length,
          (index) {
            final isSelected = index == _currentPage;
            final status = _columnStatuses[index];
            final color = Color(status.colorValue);

            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: isSelected ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
      ),
      tooltip: 'Create Issue',
      child: const Icon(Icons.add),
    );
  }

  void _openIssueDetail(BuildContext context, Issue issue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailScreen(
          issueId: '${issue.repoSlug}-${issue.issueNum}',
          repo: issue.repo,
          issueNum: issue.issueNum,
        ),
      ),
    );
  }

  void _openSearch(BuildContext context, {IssueStatus? initialStatus}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueSearchScreen(initialStatus: initialStatus),
      ),
    );
  }

  void _handleIssueContextMenu(BuildContext context, Issue issue, Offset position) {
    showIssueContextMenu(
      context: context,
      issue: issue,
      position: position,
      onViewDetails: () => _openIssueDetail(context, issue),
      onOpenInGitHub: () => _openIssueInGitHub(issue),
      onRemoveFromBoard: () => _handleRemoveFromBoard(context, issue),
      onCloseIssue: () => _handleCloseIssue(context, issue),
    );
  }

  Future<void> _openIssueInGitHub(Issue issue) async {
    final url = Uri.parse('https://github.com/${issue.repo}/issues/${issue.issueNum}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleRemoveFromBoard(BuildContext context, Issue issue) async {
    final confirmed = await RemoveConfirmationDialog.show(context, issue);
    if (!confirmed) return;

    if (!context.mounted) return;
    final provider = context.read<IssueBoardProvider>();
    await provider.hideIssue(issue);

    if (!context.mounted) return;
    _showHideToast(context, issue.title);
  }

  Future<void> _handleCloseIssue(BuildContext context, Issue issue) async {
    final confirmed = await CloseIssueDialog.show(context, issue);
    if (!confirmed) return;

    if (!context.mounted) return;
    final provider = context.read<IssueBoardProvider>();

    try {
      await provider.closeIssue(issue);
      if (!context.mounted) return;
      _showCloseToast(context, issue.title);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close issue: $e'),
          backgroundColor: const Color(0xFFDA3633),
        ),
      );
    }
  }

  void _showHideToast(BuildContext context, String issueTitle) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Issue hidden from board')),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF58A6FF),
          onPressed: () {
            context.read<IssueBoardProvider>().undoHideIssue();
          },
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF161B22),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCloseToast(BuildContext context, String issueTitle) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Issue closed on GitHub')),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF161B22),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
