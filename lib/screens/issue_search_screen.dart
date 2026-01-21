import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/issue_model.dart';
import '../providers/issue_board_provider.dart';
import '../widgets/kanban/issue_card.dart';
import 'issue_detail_screen.dart';

/// Screen for searching and filtering all issues including history
class IssueSearchScreen extends StatefulWidget {
  final IssueStatus? initialStatus;

  const IssueSearchScreen({
    super.key,
    this.initialStatus,
  });

  @override
  State<IssueSearchScreen> createState() => _IssueSearchScreenState();
}

class _IssueSearchScreenState extends State<IssueSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRepo;
  IssueStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Issues'),
      ),
      body: Consumer<IssueBoardProvider>(
        builder: (context, provider, _) {
          final filteredIssues = _filterIssues(provider.allIssues);

          return Column(
            children: [
              // Search and filters
              _buildSearchBar(context),
              _buildFilters(context, provider),
              const SizedBox(height: 16),
              // Results
              Expanded(
                child: filteredIssues.isEmpty
                    ? _buildEmptyState(context)
                    : _buildResultsList(context, filteredIssues),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by title or issue number...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, IssueBoardProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Repo filter dropdown
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedRepo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Repository',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All repos', overflow: TextOverflow.ellipsis),
                ),
                ...provider.availableRepos.map((repo) => DropdownMenuItem(
                      value: repo['full_name'],
                      child: Text(
                        repo['name'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedRepo = value),
            ),
          ),
          const SizedBox(width: 12),
          // Status filter dropdown
          Expanded(
            child: DropdownButtonFormField<IssueStatus?>(
              value: _selectedStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<IssueStatus?>(
                  value: null,
                  child: Text('All statuses', overflow: TextOverflow.ellipsis),
                ),
                ...IssueStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(status.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              status.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: const Color(0xFF8B949E).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No issues found',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6EDF3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedRepo != null || _selectedStatus != null
                  ? 'Try adjusting your filters'
                  : 'No issues have been tracked yet',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF8B949E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, List<Issue> issues) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IssueCard(
            issue: issue,
            onTap: () => _openIssueDetail(context, issue),
          ),
        );
      },
    );
  }

  List<Issue> _filterIssues(List<Issue> issues) {
    return issues.where((issue) {
      // Text search filter
      if (_searchQuery.isNotEmpty) {
        final matchesTitle = issue.title.toLowerCase().contains(_searchQuery);
        final matchesNumber = '#${issue.issueNum}'.contains(_searchQuery) ||
            issue.issueNum.toString().contains(_searchQuery);
        if (!matchesTitle && !matchesNumber) return false;
      }

      // Repo filter
      if (_selectedRepo != null && issue.repo != _selectedRepo) {
        return false;
      }

      // Status filter
      if (_selectedStatus != null && issue.status != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();
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
}
