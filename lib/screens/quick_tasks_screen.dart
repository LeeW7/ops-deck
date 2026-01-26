import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/quick_session_provider.dart';
import '../services/api_service.dart';
import '../widgets/sessions/session_card.dart';
import '../widgets/sessions/empty_sessions_state.dart';
import 'quick_chat_screen.dart';

/// Main screen displaying the list of all quick sessions
class QuickTasksScreen extends StatefulWidget {
  const QuickTasksScreen({super.key});

  @override
  State<QuickTasksScreen> createState() => _QuickTasksScreenState();
}

class _QuickTasksScreenState extends State<QuickTasksScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, String>> _availableRepos = [];
  bool _isLoadingRepos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
      _loadRepos();
    });
  }

  Future<void> _initializeProvider() async {
    final provider = context.read<QuickSessionProvider>();
    await provider.initialize();
  }

  Future<void> _loadRepos() async {
    if (_isLoadingRepos) return;

    setState(() => _isLoadingRepos = true);

    try {
      final repos = await _apiService.fetchRepos();
      if (mounted) {
        setState(() {
          _availableRepos = repos;
          _isLoadingRepos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRepos = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<QuickSessionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.sessions.isEmpty) {
            return _buildError(context, provider);
          }

          return _buildContent(context, provider);
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Quick Tasks'),
      actions: [
        // Repo filter dropdown
        Consumer<QuickSessionProvider>(
          builder: (context, provider, _) {
            if (provider.availableRepos.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildRepoFilterButton(context, provider);
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Consumer<QuickSessionProvider>(
          builder: (context, provider, _) {
            if (provider.availableRepos.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildRepoFilterChips(context, provider);
          },
        ),
      ),
    );
  }

  Widget _buildRepoFilterButton(BuildContext context, QuickSessionProvider provider) {
    final hasFilter = provider.selectedRepo != null;

    return PopupMenuButton<String?>(
      icon: Icon(
        Icons.filter_list,
        color: hasFilter
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFF8B949E),
      ),
      tooltip: 'Filter by repository',
      onSelected: (repo) {
        provider.setSelectedRepo(repo);
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text(
            'All Repositories',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
        const PopupMenuDivider(),
        for (final repo in provider.availableRepos)
          PopupMenuItem<String>(
            value: repo,
            child: Row(
              children: [
                if (provider.selectedRepo == repo)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatRepoName(repo),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRepoFilterChips(BuildContext context, QuickSessionProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // "All" chip
          _RepoFilterChip(
            label: 'All',
            isSelected: provider.selectedRepo == null,
            onTap: () => provider.setSelectedRepo(null),
          ),
          const SizedBox(width: 8),
          // Repo chips
          for (final repo in provider.availableRepos) ...[
            _RepoFilterChip(
              label: _formatRepoName(repo),
              isSelected: provider.selectedRepo == repo,
              onTap: () => provider.setSelectedRepo(
                provider.selectedRepo == repo ? null : repo,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, QuickSessionProvider provider) {
    if (provider.sessions.isEmpty) {
      return EmptySessionsState(
        onCreateSession: () => _showCreateSessionDialog(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchSessions(),
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.sessions.length,
        itemBuilder: (context, index) {
          final session = provider.sessions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SessionCard(
              session: session,
              onTap: () => _navigateToChat(context, session),
              onDelete: (session) => _handleDeleteSession(context, provider, session),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, QuickSessionProvider provider) {
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
              provider.error ?? 'An unknown error occurred',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF8B949E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                provider.clearError();
                provider.fetchSessions();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateSessionDialog(context),
      tooltip: 'New Session',
      child: const Icon(Icons.add),
    );
  }

  void _navigateToChat(BuildContext context, QuickSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickChatScreen(sessionId: session.id),
      ),
    );
  }

  Future<void> _handleDeleteSession(
    BuildContext context,
    QuickSessionProvider provider,
    QuickSession session,
  ) async {
    final confirmed = await _showDeleteConfirmationDialog(context, session);
    if (!confirmed) return;

    if (!context.mounted) return;

    final success = await provider.deleteSession(session.id);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 20),
              SizedBox(width: 8),
              Text('Session deleted'),
            ],
          ),
          backgroundColor: Color(0xFF161B22),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to delete session'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    QuickSession session,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text(
          'Delete Session',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFE6EDF3),
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this session? This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF8B949E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8B949E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFF85149),
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showCreateSessionDialog(BuildContext context) async {
    // If repos aren't loaded yet, try loading them
    if (_availableRepos.isEmpty && !_isLoadingRepos) {
      await _loadRepos();
    }

    if (!context.mounted) return;

    // If still no repos, show error
    if (_availableRepos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No repositories available. Check server configuration.'),
          backgroundColor: Color(0xFFF85149),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedRepo = await showDialog<String>(
      context: context,
      builder: (context) => _RepoSelectionDialog(repos: _availableRepos),
    );

    if (selectedRepo == null || !context.mounted) return;

    final provider = context.read<QuickSessionProvider>();
    final session = await provider.createSession(selectedRepo);

    if (!context.mounted) return;

    if (session != null) {
      // Navigate to the new session
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickChatScreen(sessionId: session.id),
        ),
      );
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatRepoName(String repo) {
    // Extract just the repo name if full path (e.g., "owner/repo" -> "repo")
    if (repo.contains('/')) {
      return repo.split('/').last;
    }
    return repo;
  }
}

/// Filter chip for repo selection
class _RepoFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RepoFilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.2)
                : const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : const Color(0xFF30363D),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isSelected ? primaryColor : const Color(0xFFE6EDF3),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting a repository when creating a new session
class _RepoSelectionDialog extends StatelessWidget {
  final List<Map<String, String>> repos;

  const _RepoSelectionDialog({required this.repos});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      title: const Text(
        'Select Repository',
        style: TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFFE6EDF3),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: repos.length,
          itemBuilder: (context, index) {
            final repo = repos[index];
            final fullName = repo['full_name'] ?? '';
            final name = repo['name'] ?? '';

            return ListTile(
              leading: const Icon(
                Icons.folder_outlined,
                color: Color(0xFF8B949E),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFFE6EDF3),
                ),
              ),
              subtitle: Text(
                fullName,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
              onTap: () => Navigator.of(context).pop(fullName),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hoverColor: const Color(0xFF21262D),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF8B949E),
            ),
          ),
        ),
      ],
    );
  }
}
