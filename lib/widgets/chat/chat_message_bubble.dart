import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';

/// Widget to display a single chat message (user or assistant).
///
/// Different styling for user vs assistant messages:
/// - User messages: right-aligned, accent color background
/// - Assistant messages: left-aligned, surface color background
class ChatMessageBubble extends StatelessWidget {
  final QuickMessage message;
  final VoidCallback? onTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onTap,
  });

  // Theme colors
  static const _backgroundColor = Color(0xFF0D1117);
  static const _surfaceColor = Color(0xFF161B22);
  static const _borderColor = Color(0xFF30363D);
  static const _accentColor = Color(0xFF00FF41);
  static const _mutedColor = Color(0xFF8B949E);
  static const _textColor = Color(0xFFE6EDF3);
  static const _userBubbleColor = Color(0xFF1F3A5F);
  static const _linkColor = Color(0xFF58A6FF);
  static const _toolColor = Color(0xFFA371F7);

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case MessageRole.user:
        return _buildUserMessage(context);
      case MessageRole.assistant:
        return _buildAssistantMessage(context);
      case MessageRole.tool:
        return _buildToolMessage(context);
      case MessageRole.system:
        return _buildSystemMessage(context);
    }
  }

  Widget _buildUserMessage(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _userBubbleColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: _linkColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: _textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            _buildTimestamp(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assistant label
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CLAUDE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                if (message.costUsd != null) _buildCostBadge(),
              ],
            ),
            const SizedBox(height: 8),
            // Message content with markdown
            MarkdownBody(
              data: message.content,
              onTapLink: (text, href, title) => _openUrl(href),
              styleSheet: _buildMarkdownStyleSheet(),
              shrinkWrap: true,
              softLineBreak: true,
            ),
            const SizedBox(height: 6),
            _buildTimestamp(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolMessage(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _toolColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool header
            Row(
              children: [
                Icon(
                  _getToolIcon(message.toolName),
                  size: 14,
                  color: _toolColor,
                ),
                const SizedBox(width: 6),
                Text(
                  message.toolName?.toUpperCase() ?? 'TOOL',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _toolColor,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _buildTimestamp(),
              ],
            ),
            if (message.toolInput != null && message.toolInput!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _truncateToolInput(message.toolInput!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: _mutedColor,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _borderColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: _mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp() {
    final hour = message.timestamp.hour;
    final minute = message.timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return Text(
      '$displayHour:$minute $period',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: _mutedColor.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildCostBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '\$${message.costUsd!.toStringAsFixed(4)}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: _accentColor,
        ),
      ),
    );
  }

  IconData _getToolIcon(String? toolName) {
    switch (toolName?.toLowerCase()) {
      case 'read':
        return Icons.description;
      case 'edit':
      case 'write':
        return Icons.edit;
      case 'bash':
        return Icons.terminal;
      case 'glob':
      case 'grep':
        return Icons.search;
      case 'web_search':
        return Icons.travel_explore;
      default:
        return Icons.build;
    }
  }

  String _truncateToolInput(String input) {
    // Try to parse as JSON and show key info, or truncate raw string
    if (input.length > 200) {
      return '${input.substring(0, 200)}...';
    }
    return input;
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: _textColor,
        height: 1.5,
      ),
      a: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: _linkColor,
        decoration: TextDecoration.underline,
      ),
      h1: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
      h2: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
      h3: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: _accentColor,
        backgroundColor: _backgroundColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: _mutedColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: _borderColor, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: const TextStyle(
        color: _accentColor,
      ),
      tableHead: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
      tableBody: const TextStyle(
        fontFamily: 'monospace',
        color: _textColor,
      ),
      tableBorder: TableBorder.all(color: _borderColor),
      tableHeadAlign: TextAlign.left,
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
