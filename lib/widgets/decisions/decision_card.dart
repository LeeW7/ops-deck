import 'package:flutter/material.dart';
import '../../models/job_model.dart';

/// A card displaying a single decision made by Claude
class DecisionCard extends StatelessWidget {
  final JobDecision decision;
  final bool isExpanded;
  final VoidCallback? onTap;

  const DecisionCard({
    super.key,
    required this.decision,
    this.isExpanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            decision.action,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE6EDF3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            decision.reasoning,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Color(0xFF8B949E),
                              height: 1.4,
                            ),
                            maxLines: isExpanded ? null : 2,
                            overflow: isExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: const Color(0xFF8B949E),
                      ),
                  ],
                ),
                if (isExpanded && decision.alternatives != null && decision.alternatives!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF30363D), height: 1),
                  const SizedBox(height: 12),
                  _buildAlternatives(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon() {
    IconData icon;
    Color color;

    switch (decision.category?.toLowerCase()) {
      case 'architecture':
        icon = Icons.account_tree;
        color = const Color(0xFF58A6FF);
        break;
      case 'library':
        icon = Icons.inventory_2;
        color = const Color(0xFFA371F7);
        break;
      case 'pattern':
        icon = Icons.grid_view;
        color = const Color(0xFF3FB950);
        break;
      case 'storage':
        icon = Icons.storage;
        color = const Color(0xFFD29922);
        break;
      case 'api':
        icon = Icons.api;
        color = const Color(0xFF58A6FF);
        break;
      case 'testing':
        icon = Icons.bug_report;
        color = const Color(0xFFF85149);
        break;
      default:
        icon = Icons.lightbulb_outline;
        color = const Color(0xFF8B949E);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildAlternatives() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ALTERNATIVES CONSIDERED',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6E7681),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: decision.alternatives!.map((alt) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                alt,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A compact inline decision chip for status bar display
class DecisionChip extends StatelessWidget {
  final int decisionCount;
  final VoidCallback? onTap;

  const DecisionChip({
    super.key,
    required this.decisionCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (decisionCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF238636).withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF238636).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 12,
              color: Color(0xFF3FB950),
            ),
            const SizedBox(width: 4),
            Text(
              '$decisionCount',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3FB950),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
