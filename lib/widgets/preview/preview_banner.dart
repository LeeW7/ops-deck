import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/preview_model.dart';

/// Banner shown when preview is ready - appears at bottom of screen
class PreviewReadyBanner extends StatelessWidget {
  final ValidationState state;
  final VoidCallback? onOpenPreview;
  final VoidCallback? onDismiss;

  const PreviewReadyBanner({
    super.key,
    required this.state,
    this.onOpenPreview,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.previewReady) {
      return const SizedBox.shrink();
    }

    final allTestsPassing = state.allTestsPassing;
    final previewUrl = state.preview?.previewUrl ?? state.preview?.downloadUrl;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allTestsPassing
              ? const Color(0xFF238636)
              : const Color(0xFFD29922),
        ),
        boxShadow: [
          BoxShadow(
            color: (allTestsPassing
                    ? const Color(0xFF238636)
                    : const Color(0xFFD29922))
                .withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenPreview ?? () => _openUrl(previewUrl),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (allTestsPassing
                            ? const Color(0xFF238636)
                            : const Color(0xFFD29922))
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    allTestsPassing ? Icons.check_circle : Icons.preview,
                    color: allTestsPassing
                        ? const Color(0xFF3FB950)
                        : const Color(0xFFD29922),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allTestsPassing
                            ? 'Preview ready to test'
                            : 'Preview ready (tests failing)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: allTestsPassing
                              ? const Color(0xFF3FB950)
                              : const Color(0xFFD29922),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (state.testResults.isNotEmpty)
                        Text(
                          '${state.totalPassed} tests passing${state.totalFailed > 0 ? ', ${state.totalFailed} failing' : ''}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                          ),
                        )
                      else
                        const Text(
                          'Tap to open preview',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF238636),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'OPEN',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF6E7681),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Compact validation status indicator for IssueCard
class ValidationIndicator extends StatelessWidget {
  final ValidationState? state;
  final bool compact;

  const ValidationIndicator({
    super.key,
    this.state,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (state == null) {
      return const SizedBox.shrink();
    }

    // Determine overall status
    final hasTests = state!.testResults.isNotEmpty;
    final allTestsPassing = state!.allTestsPassing;
    final previewReady = state!.previewReady;
    final previewDeploying = state!.preview?.status == PreviewStatus.deploying;
    final previewFailed = state!.preview?.status == PreviewStatus.failed;

    // If no meaningful state, don't show anything
    if (!hasTests && state!.preview == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactIndicator(
        hasTests: hasTests,
        allTestsPassing: allTestsPassing,
        previewReady: previewReady,
        previewDeploying: previewDeploying,
        previewFailed: previewFailed,
      );
    }

    return _buildFullIndicator(
      hasTests: hasTests,
      allTestsPassing: allTestsPassing,
      previewReady: previewReady,
      previewDeploying: previewDeploying,
      previewFailed: previewFailed,
    );
  }

  Widget _buildCompactIndicator({
    required bool hasTests,
    required bool allTestsPassing,
    required bool previewReady,
    required bool previewDeploying,
    required bool previewFailed,
  }) {
    Color color;
    IconData icon;

    if (previewDeploying) {
      color = const Color(0xFFD29922);
      icon = Icons.cloud_upload;
    } else if (previewFailed || (hasTests && !allTestsPassing)) {
      color = const Color(0xFFF85149);
      icon = Icons.error_outline;
    } else if (previewReady && allTestsPassing) {
      color = const Color(0xFF3FB950);
      icon = Icons.verified;
    } else if (previewReady) {
      color = const Color(0xFF58A6FF);
      icon = Icons.preview;
    } else if (hasTests && allTestsPassing) {
      color = const Color(0xFF3FB950);
      icon = Icons.check_circle_outline;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: previewDeploying
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : Icon(icon, size: 12, color: color),
    );
  }

  Widget _buildFullIndicator({
    required bool hasTests,
    required bool allTestsPassing,
    required bool previewReady,
    required bool previewDeploying,
    required bool previewFailed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Test status
        if (hasTests)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (allTestsPassing
                      ? const Color(0xFF3FB950)
                      : const Color(0xFFF85149))
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allTestsPassing ? Icons.check : Icons.close,
                  size: 10,
                  color: allTestsPassing
                      ? const Color(0xFF3FB950)
                      : const Color(0xFFF85149),
                ),
                const SizedBox(width: 4),
                Text(
                  '${state!.totalPassed}/${state!.totalTests}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: allTestsPassing
                        ? const Color(0xFF3FB950)
                        : const Color(0xFFF85149),
                  ),
                ),
              ],
            ),
          ),

        // Preview status
        if (state!.preview != null) ...[
          if (hasTests) const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Color(state!.preview!.status.colorValue).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (previewDeploying)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(state!.preview!.status.colorValue),
                      ),
                    ),
                  )
                else
                  Icon(
                    previewReady ? Icons.preview : Icons.cloud_off,
                    size: 10,
                    color: Color(state!.preview!.status.colorValue),
                  ),
                const SizedBox(width: 4),
                Text(
                  previewDeploying ? 'DEPLOY' : (previewReady ? 'PREVIEW' : 'FAIL'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(state!.preview!.status.colorValue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Status bar showing validation progress
class ValidationStatusBar extends StatelessWidget {
  final ValidationState state;

  const ValidationStatusBar({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          _buildStep(
            label: 'TESTS',
            isComplete: state.allTestsPassing,
            isActive: state.phase == ValidationPhase.testing,
            isFailed: state.testResults.isNotEmpty && !state.allTestsPassing,
          ),
          _buildConnector(state.allTestsPassing),
          _buildStep(
            label: 'DEPLOY',
            isComplete: state.previewReady,
            isActive: state.phase == ValidationPhase.deploying,
            isFailed: state.preview?.status == PreviewStatus.failed,
          ),
          _buildConnector(state.previewReady),
          _buildStep(
            label: 'READY',
            isComplete: state.phase == ValidationPhase.ready,
            isActive: false,
            isFailed: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String label,
    required bool isComplete,
    required bool isActive,
    required bool isFailed,
  }) {
    Color color;
    IconData icon;

    if (isFailed) {
      color = const Color(0xFFF85149);
      icon = Icons.close;
    } else if (isComplete) {
      color = const Color(0xFF3FB950);
      icon = Icons.check;
    } else if (isActive) {
      color = const Color(0xFFD29922);
      icon = Icons.more_horiz;
    } else {
      color = const Color(0xFF6E7681);
      icon = Icons.circle_outlined;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: isActive
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isComplete) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isComplete ? const Color(0xFF3FB950) : const Color(0xFF30363D),
      ),
    );
  }
}
