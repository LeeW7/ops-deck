import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'log_screen.dart';
import 'settings_screen.dart';
import 'create_issue_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JobProvider>();
      provider.initialize().then((_) {
        if (provider.isConfigured) {
          provider.startRealTimeUpdates();
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: Consumer<JobProvider>(
        builder: (context, provider, child) {
          if (!provider.isConfigured) {
            return _buildNotConfiguredView();
          }

          if (provider.isLoading && provider.jobs.isEmpty) {
            return _buildLoadingView();
          }

          if (provider.error != null && provider.jobs.isEmpty) {
            return _buildErrorView(provider.error!);
          }

          return _buildJobsList(provider);
        },
      ),
      floatingActionButton: Consumer<JobProvider>(
        builder: (context, provider, child) {
          if (!provider.isConfigured) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
              );
            },
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'NEW ISSUE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF41).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'OPS DECK',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF161B22),
      foregroundColor: const Color(0xFF00FF41),
      elevation: 0,
      actions: [
        Consumer<JobProvider>(
          builder: (context, provider, child) {
            return IconButton(
              icon: Icon(
                provider.error != null ? Icons.cloud_off : Icons.cloud_done,
                color: provider.error != null
                    ? const Color(0xFFF85149)
                    : const Color(0xFF3FB950),
              ),
              onPressed: () {
                if (provider.isConfigured) {
                  provider.fetchJobs();
                }
              },
              tooltip: 'Connection status',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            if (mounted) {
              final provider = context.read<JobProvider>();
              await provider.checkConfiguration();
              if (provider.isConfigured) {
                provider.startRealTimeUpdates();
              }
            }
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildNotConfiguredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.settings_ethernet,
                    size: 64,
                    color: Color(0xFF8B949E),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SERVER NOT CONFIGURED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE6EDF3),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Configure the server URL to start monitoring agents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      if (mounted) {
                        final provider = context.read<JobProvider>();
                        await provider.checkConfiguration();
                        if (provider.isConfigured) {
                          provider.startRealTimeUpdates();
                        }
                      }
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('CONFIGURE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'CONNECTING...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDA3633)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFF85149),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'CONNECTION ERROR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF85149),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      context.read<JobProvider>().fetchJobs();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('RETRY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDA3633),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList(JobProvider provider) {
    final jobs = provider.sortedJobs;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: const Color(0xFF8B949E).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'NO ACTIVE JOBS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B949E),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for new tasks...',
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

    return RefreshIndicator(
      onRefresh: () => provider.fetchJobs(),
      color: const Color(0xFF00FF41),
      backgroundColor: const Color(0xFF161B22),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          return _JobCard(job: jobs[index]);
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(),
          width: job.needsApproval ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LogScreen(job: job),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.issueTitle.isNotEmpty
                                    ? job.issueTitle
                                    : 'ISSUE #${job.issueId}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE6EDF3),
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPhaseBadge(),
                            const SizedBox(width: 4),
                            _buildStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              size: 14,
                              color: Color(0xFF8B949E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              job.repo.split('/').last,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFF58A6FF),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Color(0xFF8B949E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              job.formattedStartTime,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFF8B949E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!job.needsApproval) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF8B949E),
                    ),
                  ],
                ],
              ),
              // Approval buttons for waiting_approval status
              if (job.needsApproval) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0883E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF0883E).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFF0883E),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ACTION REQUIRED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF0883E),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final provider = context.read<JobProvider>();
                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    provider.approveJob(job.issueId);
                                  },
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('APPROVE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF238636),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    provider.rejectJob(job.issueId);
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('REJECT'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF85149),
                                    side: const BorderSide(color: Color(0xFFF85149)),
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (job.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDA3633).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    job.error!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFF85149),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: _getStatusIcon(),
      ),
    );
  }

  Widget _getStatusIcon() {
    switch (job.jobStatus) {
      case JobStatus.running:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3FB950)),
          ),
        );
      case JobStatus.failed:
        return const Icon(
          Icons.error,
          color: Color(0xFFF85149),
          size: 24,
        );
      case JobStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF3FB950),
          size: 24,
        );
      case JobStatus.pending:
        return const Icon(
          Icons.hourglass_empty,
          color: Color(0xFF8B949E),
          size: 24,
        );
      case JobStatus.waitingApproval:
        return const Icon(
          Icons.front_hand,
          color: Color(0xFFF0883E),
          size: 24,
        );
      case JobStatus.rejected:
        return const Icon(
          Icons.cancel,
          color: Color(0xFFF85149),
          size: 24,
        );
      default:
        return const Icon(
          Icons.help_outline,
          color: Color(0xFF8B949E),
          size: 24,
        );
    }
  }

  Color _getStatusColor() {
    switch (job.jobStatus) {
      case JobStatus.running:
        return const Color(0xFF3FB950);
      case JobStatus.failed:
      case JobStatus.rejected:
        return const Color(0xFFF85149);
      case JobStatus.completed:
        return const Color(0xFF3FB950);
      case JobStatus.pending:
        return const Color(0xFF8B949E);
      case JobStatus.waitingApproval:
        return const Color(0xFFF0883E);
      default:
        return const Color(0xFF8B949E);
    }
  }

  Color _getBorderColor() {
    switch (job.jobStatus) {
      case JobStatus.running:
        return const Color(0xFF238636);
      case JobStatus.failed:
      case JobStatus.rejected:
        return const Color(0xFFDA3633);
      case JobStatus.waitingApproval:
        return const Color(0xFFF0883E);
      default:
        return const Color(0xFF30363D);
    }
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        job.status.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPhaseBadge() {
    final (label, color) = _getPhaseInfo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  (String, Color) _getPhaseInfo() {
    final cmd = job.command.toLowerCase();
    if (cmd.contains('plan')) {
      return ('PLAN', const Color(0xFF58A6FF));
    } else if (cmd.contains('implement')) {
      return ('IMPL', const Color(0xFFA371F7));
    } else if (cmd.contains('retro')) {
      return ('RETRO', const Color(0xFF3FB950));
    } else if (cmd.contains('revise')) {
      return ('REVISE', const Color(0xFFF0883E));
    }
    return ('JOB', const Color(0xFF8B949E));
  }
}
