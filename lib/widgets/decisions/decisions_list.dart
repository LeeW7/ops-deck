import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import 'decision_card.dart';

/// An expandable list of decisions made by Claude
class DecisionsList extends StatefulWidget {
  final List<JobDecision> decisions;
  final bool initiallyExpanded;

  const DecisionsList({
    super.key,
    required this.decisions,
    this.initiallyExpanded = false,
  });

  @override
  State<DecisionsList> createState() => _DecisionsListState();
}

class _DecisionsListState extends State<DecisionsList> {
  late bool _isExpanded;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decisions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF238636).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Color(0xFF3FB950),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DECISIONS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE6EDF3),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.decisions.length} choice${widget.decisions.length == 1 ? '' : 's'} made',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF8B949E),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_isExpanded) ...[
            const Divider(color: Color(0xFF30363D), height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: List.generate(widget.decisions.length, (index) {
                  final decision = widget.decisions[index];
                  return DecisionCard(
                    decision: decision,
                    isExpanded: _expandedIndex == index,
                    onTap: () => setState(() {
                      _expandedIndex = _expandedIndex == index ? null : index;
                    }),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact summary banner for decisions
class DecisionsSummaryBanner extends StatelessWidget {
  final int decisionCount;
  final VoidCallback? onTap;

  const DecisionsSummaryBanner({
    super.key,
    required this.decisionCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (decisionCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF238636).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF238636).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: Color(0xFF3FB950),
            ),
            const SizedBox(width: 8),
            Text(
              '$decisionCount decision${decisionCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3FB950),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF3FB950),
            ),
          ],
        ),
      ),
    );
  }
}
