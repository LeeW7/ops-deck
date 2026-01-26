import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input bar widget for the chat screen.
///
/// Features:
/// - Text input field with hint "Ask Claude..."
/// - Send button (icon button)
/// - Disabled state when streaming or loading
/// - Handles submit on enter key
/// - Clear input on send
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isEnabled;
  final String? hintText;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isEnabled = true,
    this.hintText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;

  // Theme colors
  static const _backgroundColor = Color(0xFF0D1117);
  static const _surfaceColor = Color(0xFF161B22);
  static const _borderColor = Color(0xFF30363D);
  static const _accentColor = Color(0xFF00FF41);
  static const _mutedColor = Color(0xFF8B949E);
  static const _textColor = Color(0xFFC9D1D9);
  static const _hintColor = Color(0xFF6E7681);
  static const _sendButtonColor = Color(0xFF58A6FF);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(
          top: BorderSide(color: _borderColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildTextField(),
            ),
            const SizedBox(width: 12),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        // Handle Enter key without shift to submit
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _handleSubmit();
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.isEnabled,
        maxLines: 4,
        minLines: 1,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: _textColor,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Ask Claude...',
          hintStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: _hintColor,
          ),
          filled: true,
          fillColor: widget.isEnabled ? _backgroundColor : _backgroundColor.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accentColor),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _borderColor.withValues(alpha: 0.5)),
          ),
        ),
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = widget.isEnabled && _hasText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: canSend ? _sendButtonColor : _borderColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canSend ? _handleSubmit : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.send_rounded,
                key: ValueKey(canSend),
                size: 24,
                color: canSend ? Colors.white : _mutedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact input bar variant for inline usage
class ChatInputBarCompact extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isEnabled;
  final String? hintText;

  const ChatInputBarCompact({
    super.key,
    required this.onSend,
    this.isEnabled = true,
    this.hintText,
  });

  @override
  State<ChatInputBarCompact> createState() => _ChatInputBarCompactState();
}

class _ChatInputBarCompactState extends State<ChatInputBarCompact> {
  late TextEditingController _controller;
  bool _hasText = false;

  static const _backgroundColor = Color(0xFF0D1117);
  static const _borderColor = Color(0xFF30363D);
  static const _textColor = Color(0xFFC9D1D9);
  static const _hintColor = Color(0xFF6E7681);
  static const _sendButtonColor = Color(0xFF58A6FF);
  static const _mutedColor = Color(0xFF8B949E);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;

    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.isEnabled && _hasText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.isEnabled,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: _textColor,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Ask Claude...',
                hintStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: _hintColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          IconButton(
            onPressed: canSend ? _handleSubmit : null,
            icon: Icon(
              Icons.send_rounded,
              color: canSend ? _sendButtonColor : _mutedColor,
            ),
            style: IconButton.styleFrom(
              backgroundColor: canSend ? _sendButtonColor.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
