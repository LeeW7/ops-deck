import 'package:flutter/material.dart';

/// Filter chips for selecting repositories
class RepoFilterChips extends StatelessWidget {
  final List<Map<String, String>> repos;
  final Set<String> selectedRepos;
  final void Function(String) onToggle;
  final VoidCallback? onClearAll;

  const RepoFilterChips({
    super.key,
    required this.repos,
    required this.selectedRepos,
    required this.onToggle,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (repos.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // "All" chip when filters are active
          if (selectedRepos.isNotEmpty) ...[
            _FilterChip(
              label: 'All',
              isSelected: false,
              onTap: onClearAll,
              icon: Icons.clear,
            ),
            const SizedBox(width: 8),
          ],
          // Repo chips
          for (final repo in repos) ...[
            _FilterChip(
              label: repo['name'] ?? '',
              isSelected: selectedRepos.contains(repo['full_name']),
              onTap: () => onToggle(repo['full_name'] ?? ''),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.2)
                : const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : const Color(0xFF30363D),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? primaryColor : const Color(0xFF8B949E),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isSelected ? primaryColor : const Color(0xFFE6EDF3),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
