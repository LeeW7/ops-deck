import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/preview_model.dart';

/// Card displaying preview deployment status and URL
class PreviewCard extends StatelessWidget {
  final PreviewDeployment? preview;
  final bool isLoading;
  final bool isTriggering;
  final VoidCallback? onTrigger;
  final VoidCallback? onRefresh;

  const PreviewCard({
    super.key,
    this.preview,
    this.isLoading = false,
    this.isTriggering = false,
    this.onTrigger,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (preview == null) {
      return _buildEmptyState(context);
    }

    return _buildPreviewContent(context);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading preview...',
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color: Color(0xFF6E7681),
          ),
          const SizedBox(height: 12),
          const Text(
            'No preview available',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Deploy a preview to test your changes',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF6E7681),
            ),
            textAlign: TextAlign.center,
          ),
          if (onTrigger != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isTriggering ? null : onTrigger,
              icon: isTriggering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.rocket_launch, size: 16),
              label: Text(isTriggering ? 'DEPLOYING...' : 'DEPLOY PREVIEW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    final statusColor = Color(preview!.status.colorValue);
    final isReady = preview!.status == PreviewStatus.ready;
    final isFailed = preview!.status == PreviewStatus.failed;
    final isDeploying = preview!.status == PreviewStatus.deploying;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PREVIEW',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B949E),
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  preview!.status.displayName,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Deploying animation
          if (isDeploying) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFF30363D),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD29922)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Deploying preview...',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFD29922),
                ),
              ),
            ),
          ],

          // Error message
          if (isFailed && preview!.errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF85149).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Color(0xFFF85149),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preview!.errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFF85149),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onTrigger != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isTriggering ? null : onTrigger,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('RETRY DEPLOYMENT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF58A6FF),
                      side: const BorderSide(color: Color(0xFF58A6FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],

          // Preview URL (web)
          if (isReady && preview!.previewUrl != null) ...[
            _buildUrlSection(
              context,
              icon: Icons.open_in_browser,
              label: 'Web Preview',
              url: preview!.previewUrl!,
            ),
          ],

          // Download URL (mobile)
          if (isReady && preview!.downloadUrl != null) ...[
            _buildUrlSection(
              context,
              icon: Icons.download,
              label: 'Download APK',
              url: preview!.downloadUrl!,
            ),
          ],

          // QR Code placeholder (for mobile)
          if (isReady && preview!.qrCodeUrl != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_2,
                          size: 100,
                          color: Color(0xFF0D1117),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan to install on device',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Expiration info
          if (isReady && preview!.expirationText != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 12,
                    color: Color(0xFF6E7681),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    preview!.expirationText!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF6E7681),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Project type info
          if (preview!.projectType != ProjectType.unknown) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(
                    _getProjectTypeIcon(preview!.projectType),
                    size: 12,
                    color: const Color(0xFF6E7681),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${preview!.projectType.displayName} - ${preview!.projectType.previewPlatform}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF6E7681),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlSection(BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF8B949E)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              url,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF58A6FF),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('OPEN'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF58A6FF),
                      side: const BorderSide(color: Color(0xFF58A6FF)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyUrl(context, url),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('COPY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProjectTypeIcon(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Icons.phone_android;
      case ProjectType.web:
        return Icons.web;
      case ProjectType.backend:
        return Icons.dns;
      case ProjectType.library:
        return Icons.library_books;
      case ProjectType.unknown:
        return Icons.help_outline;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'URL copied to clipboard',
          style: TextStyle(fontFamily: 'monospace'),
        ),
        backgroundColor: Color(0xFF238636),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Compact preview status chip for cards/headers
class PreviewStatusChip extends StatelessWidget {
  final PreviewStatus status;
  final VoidCallback? onTap;

  const PreviewStatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(status.colorValue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == PreviewStatus.deploying)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD29922)),
                ),
              )
            else
              Icon(
                _getStatusIcon(status),
                size: 12,
                color: color,
              ),
            const SizedBox(width: 4),
            Text(
              status.displayName,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(PreviewStatus status) {
    switch (status) {
      case PreviewStatus.pending:
        return Icons.schedule;
      case PreviewStatus.deploying:
        return Icons.cloud_upload;
      case PreviewStatus.ready:
        return Icons.check_circle;
      case PreviewStatus.failed:
        return Icons.error;
      case PreviewStatus.expired:
        return Icons.timer_off;
    }
  }
}
