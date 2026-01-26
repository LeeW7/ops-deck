import 'package:flutter/material.dart';

/// Streaming/typing indicator widget.
///
/// Shows "Claude is thinking..." with animated dots or pulse effect.
/// Can also display accumulated streaming content if provided.
class StreamingIndicator extends StatefulWidget {
  /// The accumulated streaming content to display
  final String? streamingContent;

  /// Optional custom thinking text
  final String? thinkingText;

  /// Whether to show the indicator
  final bool isVisible;

  const StreamingIndicator({
    super.key,
    this.streamingContent,
    this.thinkingText,
    this.isVisible = true,
  });

  @override
  State<StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Theme colors
  static const _surfaceColor = Color(0xFF161B22);
  static const _borderColor = Color(0xFF30363D);
  static const _accentColor = Color(0xFF00FF41);
  static const _mutedColor = Color(0xFF8B949E);
  static const _textColor = Color(0xFFE6EDF3);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.isVisible ? 1.0 : 0.0,
      child: Container(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThinkingHeader(),
            if (widget.streamingContent != null &&
                widget.streamingContent!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStreamingContent(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing indicator
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: _fadeAnimation.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: _fadeAnimation.value * 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          widget.thinkingText ?? 'Claude is thinking',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: _mutedColor,
          ),
        ),
        const SizedBox(width: 4),
        _buildAnimatedDots(),
      ],
    );
  }

  Widget _buildAnimatedDots() {
    return SizedBox(
      width: 24,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _animationController.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final dotProgress = ((progress * 3) - index).clamp(0.0, 1.0);
              final opacity = (dotProgress < 0.5)
                  ? dotProgress * 2
                  : (1 - dotProgress) * 2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  '.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _mutedColor.withValues(alpha: 0.3 + (opacity * 0.7)),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildStreamingContent() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          widget.streamingContent!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: _textColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Compact inline streaming indicator
class StreamingIndicatorCompact extends StatefulWidget {
  const StreamingIndicatorCompact({super.key});

  @override
  State<StreamingIndicatorCompact> createState() =>
      _StreamingIndicatorCompactState();
}

class _StreamingIndicatorCompactState extends State<StreamingIndicatorCompact>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _accentColor = Color(0xFF00FF41);
  static const _mutedColor = Color(0xFF8B949E);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPulsingDot(),
          const SizedBox(width: 8),
          const Text(
            'Thinking',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _mutedColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.8 + (0.4 * (0.5 + 0.5 * (1 - (_controller.value * 2 - 1).abs())));
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _accentColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Three-dot bounce animation indicator
class ThreeDotsIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const ThreeDotsIndicator({
    super.key,
    this.color,
    this.size = 8,
  });

  @override
  State<ThreeDotsIndicator> createState() => _ThreeDotsIndicatorState();
}

class _ThreeDotsIndicatorState extends State<ThreeDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF00FF41);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay) % 1.0;
            final bounce = progress < 0.5
                ? 4 * progress * progress * progress
                : 1 - ((-2 * progress + 2).abs() * (-2 * progress + 2).abs() * (-2 * progress + 2).abs()) / 2;
            final offset = -8 * bounce;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
