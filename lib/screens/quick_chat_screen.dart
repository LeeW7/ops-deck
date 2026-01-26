import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quick_session_provider.dart';
import '../widgets/chat/chat_message_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/streaming_indicator.dart';

/// Screen for a single quick chat session.
///
/// Displays chat messages, handles WebSocket streaming, and provides
/// an input bar for sending messages to Claude.
class QuickChatScreen extends StatefulWidget {
  final String sessionId;

  const QuickChatScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<QuickChatScreen> createState() => _QuickChatScreenState();
}

class _QuickChatScreenState extends State<QuickChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  StreamSubscription? _connectionSubscription;

  // Theme colors
  static const _backgroundColor = Color(0xFF0D1117);
  static const _surfaceColor = Color(0xFF161B22);
  static const _borderColor = Color(0xFF30363D);
  static const _accentColor = Color(0xFF00FF41);
  static const _mutedColor = Color(0xFF8B949E);
  static const _textColor = Color(0xFFE6EDF3);
  static const _errorColor = Color(0xFFF85149);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
      _focusInput();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _initializeSession() {
    final provider = context.read<QuickSessionProvider>();
    provider.loadSession(widget.sessionId);

    // Listen for streaming changes to auto-scroll
    provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _scrollToBottom();
  }

  void _focusInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String content) async {
    final provider = context.read<QuickSessionProvider>();
    await provider.sendMessage(content);
    _scrollToBottom();
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          'DELETE SESSION',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: _textColor,
            letterSpacing: 1,
          ),
        ),
        content: const Text(
          'This will permanently delete this chat session and all messages. This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _mutedColor,
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
                color: _mutedColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteSession();
    }
  }

  Future<void> _deleteSession() async {
    final provider = context.read<QuickSessionProvider>();
    final success = await provider.deleteSession(widget.sessionId);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        _showErrorSnackbar(provider.error ?? 'Failed to delete session');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        backgroundColor: _errorColor,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _handleReconnect() {
    final provider = context.read<QuickSessionProvider>();
    provider.loadSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(context),
      body: Consumer<QuickSessionProvider>(
        builder: (context, provider, _) {
          // Handle loading state
          if (provider.isLoading && provider.messages.isEmpty) {
            return _buildLoadingState();
          }

          // Handle error state (when session failed to load)
          if (provider.error != null && provider.currentSession == null) {
            return _buildErrorState(provider.error!);
          }

          return Column(
            children: [
              // Connection status bar
              _buildConnectionStatusBar(provider),
              // Messages list
              Expanded(
                child: _buildMessagesList(provider),
              ),
              // Streaming indicator
              if (provider.isStreaming)
                StreamingIndicator(
                  streamingContent: provider.streamingContent,
                  isVisible: true,
                ),
              // Input bar
              ChatInputBar(
                onSend: _sendMessage,
                isEnabled: !provider.isStreaming && !provider.isLoading,
                hintText: 'Ask Claude...',
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Consumer<QuickSessionProvider>(
        builder: (context, provider, _) {
          final session = provider.currentSession;
          final repoName = session?.repo.split('/').last ?? 'Chat';
          return Text(
            repoName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
            ),
          );
        },
      ),
      backgroundColor: _surfaceColor,
      foregroundColor: _accentColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Connection status indicator
        Consumer<QuickSessionProvider>(
          builder: (context, provider, _) {
            return _buildConnectionIndicator(provider);
          },
        ),
        // Delete action
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _showDeleteConfirmation,
          tooltip: 'Delete session',
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator(QuickSessionProvider provider) {
    Color color;
    String tooltip;

    if (provider.isWebSocketConnected) {
      color = const Color(0xFF238636);
      tooltip = 'Connected';
    } else if (provider.isLoading) {
      color = const Color(0xFFD29922);
      tooltip = 'Connecting...';
    } else {
      color = _mutedColor;
      tooltip = 'Disconnected';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: provider.isWebSocketConnected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBar(QuickSessionProvider provider) {
    // Only show if disconnected or reconnecting
    if (provider.isWebSocketConnected) {
      return const SizedBox.shrink();
    }

    final isConnecting = provider.isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          if (isConnecting) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD29922)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Connecting...',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFD29922),
              ),
            ),
          ] else ...[
            const Icon(
              Icons.cloud_off,
              size: 14,
              color: _mutedColor,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Disconnected from session',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _mutedColor,
                ),
              ),
            ),
            TextButton(
              onPressed: _handleReconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'RECONNECT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesList(QuickSessionProvider provider) {
    final messages = provider.messages;

    if (messages.isEmpty) {
      return _buildEmptyState(provider);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return ChatMessageBubble(
          message: messages[index],
        );
      },
    );
  }

  Widget _buildEmptyState(QuickSessionProvider provider) {
    final session = provider.currentSession;
    final repoName = session?.repo ?? 'this repository';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NEW SESSION',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a conversation with Claude about $repoName',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _mutedColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUGGESTIONS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _mutedColor,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 12),
                  _SuggestionItem(
                    icon: Icons.bug_report,
                    text: 'Help me debug an issue',
                  ),
                  SizedBox(height: 8),
                  _SuggestionItem(
                    icon: Icons.code,
                    text: 'Explain this code',
                  ),
                  SizedBox(height: 8),
                  _SuggestionItem(
                    icon: Icons.edit_note,
                    text: 'Refactor a function',
                  ),
                  SizedBox(height: 8),
                  _SuggestionItem(
                    icon: Icons.quiz,
                    text: 'Answer a quick question',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading session...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: _mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: _errorColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'FAILED TO LOAD',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _errorColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _mutedColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('GO BACK'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mutedColor,
                    side: const BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _handleReconnect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: _backgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
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
}

/// Helper widget for suggestion items in empty state
class _SuggestionItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SuggestionItem({
    required this.icon,
    required this.text,
  });

  static const _mutedColor = Color(0xFF8B949E);
  static const _accentColor = Color(0xFF00FF41);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: _accentColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: _mutedColor,
          ),
        ),
      ],
    );
  }
}
