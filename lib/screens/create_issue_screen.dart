import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';

class CreateIssueScreen extends StatefulWidget {
  const CreateIssueScreen({super.key});

  @override
  State<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends State<CreateIssueScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  IssueProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<IssueProvider>();
      _provider!.addListener(_syncControllers);
      _provider!.fetchRepos();
    });
  }

  void _syncControllers() {
    if (!mounted || _provider == null) return;
    // Sync both title and body (AI enhancement updates both)
    if (_titleController.text != _provider!.title) {
      _titleController.text = _provider!.title;
    }
    if (_bodyController.text != _provider!.body) {
      _bodyController.text = _provider!.body;
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_syncControllers);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'CREATE ISSUE',
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
      body: Consumer<IssueProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success message
                if (provider.successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF238636).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF238636)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF3FB950),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.successMessage!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF3FB950),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error message
                if (provider.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDA3633).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDA3633)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error,
                          color: Color(0xFFF85149),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFFF85149),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFF85149)),
                          onPressed: () => provider.clearError(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Repository selector
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
                      const Text(
                        'REPOSITORY',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B949E),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (provider.isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: provider.selectedRepo,
                          dropdownColor: const Color(0xFF161B22),
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            prefixIcon: const Icon(
                              Icons.folder,
                              size: 18,
                              color: Color(0xFF58A6FF),
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
                          hint: const Text(
                            'Select a repository',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF8B949E),
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFE6EDF3),
                          ),
                          items: provider.repos.map((repo) {
                            return DropdownMenuItem<String>(
                              value: repo['full_name'],
                              child: Text(repo['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) => provider.setSelectedRepo(value),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Title input
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
                      const Text(
                        'TITLE / IDEA',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B949E),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        // Don't use onChanged - it causes focus issues due to Consumer rebuild
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFE6EDF3),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Add dark mode to settings',
                          hintStyle: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF8B949E),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
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
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Body input
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
                      const Text(
                        'DESCRIPTION (OPTIONAL)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B949E),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bodyController,
                        // Don't use onChanged - it causes focus issues due to Consumer rebuild
                        maxLines: 8,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFE6EDF3),
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add details, then use AI to polish...',
                          hintStyle: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF8B949E),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
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
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: provider.isEnhancing
                              ? null
                              : () {
                                  // Save values BEFORE any provider calls (notifyListeners overwrites controllers)
                                  final title = _titleController.text;
                                  final body = _bodyController.text;
                                  provider.setTitle(title);
                                  provider.setBody(body);
                                  provider.enhanceWithAI();
                                },
                          icon: provider.isEnhancing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA371F7)),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            provider.isEnhancing ? 'POLISHING...' : 'POLISH WITH AI',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA371F7),
                            side: const BorderSide(color: Color(0xFFA371F7)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Create button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: provider.isCreating
                        ? null
                        : () async {
                            // Save values BEFORE any provider calls (notifyListeners overwrites controllers)
                            final title = _titleController.text;
                            final body = _bodyController.text;
                            provider.setTitle(title);
                            provider.setBody(body);
                            final success = await provider.createIssue();
                            if (success && mounted) {
                              // Navigate back to dashboard
                              Navigator.pop(context);
                            }
                          },
                    icon: provider.isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.rocket_launch),
                    label: Text(
                      provider.isCreating ? 'CREATING...' : 'CREATE & QUEUE',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF238636).withOpacity(0.5),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF8B949E),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Issue will be created with cmd:plan-headless label and automatically picked up by the agent.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
