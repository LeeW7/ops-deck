import 'package:flutter/material.dart';
import '../../models/preview_model.dart';

/// Card displaying test results summary
class TestResultsCard extends StatelessWidget {
  final List<TestResult> results;
  final bool initiallyExpanded;
  final VoidCallback? onViewFailures;

  const TestResultsCard({
    super.key,
    required this.results,
    this.initiallyExpanded = false,
    this.onViewFailures,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _buildEmptyState();
    }

    final totalPassed = results.fold<int>(0, (sum, r) => sum + r.passed);
    final totalFailed = results.fold<int>(0, (sum, r) => sum + r.failed);
    final totalSkipped = results.fold<int>(0, (sum, r) => sum + r.skipped);
    final allPassing = totalFailed == 0 && totalPassed > 0;

    // Get best coverage from any result
    String? coverage;
    for (final result in results) {
      if (result.coveragePercent != null) {
        coverage = result.coveragePercent;
        break;
      }
    }

    // Collect all failures
    final allFailures = results.expand((r) => r.failures).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allPassing ? const Color(0xFF238636) : const Color(0xFFF85149),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  allPassing ? Icons.check_circle : Icons.error,
                  color: allPassing ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'TEST RESULTS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B949E),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Test counts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCountChip(
                  Icons.check_circle_outline,
                  totalPassed.toString(),
                  'passed',
                  const Color(0xFF3FB950),
                ),
                const SizedBox(width: 12),
                _buildCountChip(
                  Icons.cancel_outlined,
                  totalFailed.toString(),
                  'failed',
                  const Color(0xFFF85149),
                ),
                const SizedBox(width: 12),
                _buildCountChip(
                  Icons.remove_circle_outline,
                  totalSkipped.toString(),
                  'skipped',
                  const Color(0xFF8B949E),
                ),
              ],
            ),
          ),

          // Coverage
          if (coverage != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: Color(0xFF8B949E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Coverage: $coverage',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Failures section
          if (allFailures.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF30363D), height: 1),
            _buildFailuresSection(allFailures),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.science_outlined,
            size: 32,
            color: Color(0xFF6E7681),
          ),
          SizedBox(height: 12),
          Text(
            'No test results yet',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tests will run automatically after implementation',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF6E7681),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(IconData icon, String count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFailuresSection(List<TestFailure> failures) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: initiallyExpanded,
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber,
            size: 16,
            color: Color(0xFFF85149),
          ),
          const SizedBox(width: 8),
          Text(
            '${failures.length} failure${failures.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFF85149),
            ),
          ),
        ],
      ),
      children: [
        Container(
          color: const Color(0xFF0D1117),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: failures.take(5).map((f) => _buildFailureItem(f)).toList(),
          ),
        ),
        if (failures.length > 5)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: onViewFailures,
              child: Text(
                'View all ${failures.length} failures',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF58A6FF),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFailureItem(TestFailure failure) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF21262D)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  failure.testName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (failure.location != null)
                Text(
                  failure.location!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF6E7681),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            failure.message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFFF85149),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Compact test status chip for displaying in headers/cards
class TestStatusChip extends StatelessWidget {
  final int passed;
  final int failed;
  final int skipped;
  final VoidCallback? onTap;

  const TestStatusChip({
    super.key,
    required this.passed,
    required this.failed,
    required this.skipped,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allPassing = failed == 0 && passed > 0;
    final color = allPassing ? const Color(0xFF3FB950) : const Color(0xFFF85149);

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
            Icon(
              allPassing ? Icons.check : Icons.close,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$passed/${ passed + failed}',
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
}

/// Test results summary widget for quick view
class TestResultsSummary extends StatelessWidget {
  final ValidationState state;
  final VoidCallback? onTap;

  const TestResultsSummary({
    super.key,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (state.testResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final passed = state.totalPassed;
    final failed = state.totalFailed;
    final allPassing = state.allTestsPassing;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: allPassing
                ? const Color(0xFF238636).withOpacity(0.5)
                : const Color(0xFFF85149).withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              allPassing ? Icons.check_circle : Icons.error,
              size: 20,
              color: allPassing ? const Color(0xFF3FB950) : const Color(0xFFF85149),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allPassing ? 'All tests passing' : '$failed test${failed == 1 ? '' : 's'} failing',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: allPassing ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                    ),
                  ),
                  Text(
                    '$passed passed${state.totalSkipped > 0 ? ', ${state.totalSkipped} skipped' : ''}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ],
              ),
            ),
            if (state.bestCoverage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  state.bestCoverage!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF6E7681),
            ),
          ],
        ),
      ),
    );
  }
}
