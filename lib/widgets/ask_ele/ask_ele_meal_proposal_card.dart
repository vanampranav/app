import 'package:flutter/material.dart';
import '../../models/ask_ele_proposal.dart';
import '../../theme/app_theme.dart';

class AskEleMealProposalCard extends StatelessWidget {
  final MealProposal proposal;
  final VoidCallback? onConfirmAndLog;
  final bool isLogging;
  final bool isLogged;

  const AskEleMealProposalCard({
    super.key,
    required this.proposal,
    this.onConfirmAndLog,
    this.isLogging = false,
    this.isLogged = false,
  });

  String _formatMealType(String? type) {
    if (type == null || type.isEmpty) return 'Unspecified Meal';
    final norm = type.toLowerCase().trim();
    if (norm == 'breakfast') return 'Breakfast';
    if (norm == 'lunch') return 'Lunch';
    if (norm == 'dinner') return 'Dinner';
    if (norm == 'snacks' || norm == 'snack') return 'Snack';
    return '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}';
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'needs_serving':
        return 'Needs Serving Size';
      case 'needs_quantity':
        return 'Needs Quantity';
      case 'needs_food_match':
        return 'Needs Food Match';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Unresolved';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalNutr = proposal.resolvedNutritionTotal;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isLogged
              ? AppTheme.lime
              : (proposal.readyToLog
                  ? AppTheme.lime.withValues(alpha: 0.5)
                  : AppTheme.purple.withValues(alpha: 0.5)),
          width: isLogged ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header / Meal Type ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.lime,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatMealType(proposal.mealType),
                    style: AppTheme.headingSM.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isLogged
                      ? AppTheme.lime.withValues(alpha: 0.2)
                      : (proposal.readyToLog
                          ? AppTheme.lime.withValues(alpha: 0.15)
                          : AppTheme.warning.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isLogged
                        ? AppTheme.lime
                        : (proposal.readyToLog
                            ? AppTheme.lime
                            : AppTheme.warning),
                    width: 1,
                  ),
                ),
                child: Text(
                  isLogged
                      ? '✓ Logged'
                      : (proposal.readyToLog ? 'Ready to Log' : 'Needs Review'),
                  style: AppTheme.labelSM.copyWith(
                    fontSize: 10,
                    color: isLogged
                        ? AppTheme.lime
                        : (proposal.readyToLog
                            ? AppTheme.lime
                            : AppTheme.warning),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: AppTheme.md),

          // ── Items List ──────────────────────────────────────────────────────
          Text(
            'ITEMS (${proposal.items.length})',
            style: AppTheme.labelSM.copyWith(
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.sm),

          ...proposal.items.map((item) => _buildItemTile(context, item)),

          const SizedBox(height: AppTheme.md),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: AppTheme.md),

          // ── Estimated Nutrition Total Summary ──────────────────────────────
          if (totalNutr != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Total',
                  style: AppTheme.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '~${totalNutr.calories.round()} kcal',
                  style: AppTheme.headingSM.copyWith(
                    color: AppTheme.lime,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildMacroPill('Protein', '${totalNutr.protein.round()}g'),
                const SizedBox(width: 8),
                _buildMacroPill('Carbs', '${totalNutr.carbs.round()}g'),
                const SizedBox(width: 8),
                _buildMacroPill('Fat', '${totalNutr.fat.round()}g'),
              ],
            ),
            if (proposal.unresolvedItemCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Total includes resolved items only (${proposal.resolvedItemCount} of ${proposal.items.length}).',
                style: AppTheme.bodySM.copyWith(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            Text(
              'No items resolved yet. Clarify details above to estimate nutrition.',
              style: AppTheme.bodySM.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: AppTheme.md),

          // ── Confirm & Log Action Button ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: _buildLogButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogButton() {
    if (isLogged) {
      return ElevatedButton.icon(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.surface3,
          disabledForegroundColor: AppTheme.lime,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        ),
        icon: const Icon(Icons.check_circle_rounded,
            size: 18, color: AppTheme.lime),
        label: Text(
          'Logged ✓',
          style: AppTheme.labelMD.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.lime,
          ),
        ),
      );
    }

    if (isLogging) {
      return ElevatedButton.icon(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.lime.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        ),
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.black,
          ),
        ),
        label: Text(
          'Logging meal...',
          style: AppTheme.labelMD.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: proposal.readyToLog ? onConfirmAndLog : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: proposal.readyToLog ? AppTheme.lime : AppTheme.surface3,
        foregroundColor:
            proposal.readyToLog ? Colors.black : AppTheme.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
      ),
      icon: Icon(
        proposal.readyToLog
            ? Icons.check_circle_outline_rounded
            : Icons.lock_clock_outlined,
        size: 18,
      ),
      label: Text(
        proposal.readyToLog ? 'Confirm & Log' : 'Clarification Needed',
        style: AppTheme.labelMD.copyWith(
          fontWeight: FontWeight.bold,
          color: proposal.readyToLog ? Colors.black : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, MealProposalItem item) {
    final foodName = item.matchedFoodName ?? item.interpretedName;
    final calories = item.nutrition?.calories;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: item.isResolved
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodName,
                      style: AppTheme.bodyMD.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (item.brandName != null && item.brandName!.isNotEmpty)
                      Text(
                        item.brandName!,
                        style: AppTheme.bodySM.copyWith(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _buildServingText(item),
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isResolved && calories != null)
                Text(
                  '~${calories.round()} kcal',
                  style: AppTheme.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lime,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatStatusLabel(item.status),
                    style: AppTheme.labelSM.copyWith(
                      fontSize: 10,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildServingText(MealProposalItem item) {
    if (!item.isResolved) {
      return 'Amount not specified';
    }
    if (item.matchedServingDescription != null &&
        item.matchedServingDescription!.isNotEmpty) {
      final qty = item.resolvedQuantity ?? item.requestedQuantity ?? 1;
      final weight =
          item.weightGrams != null ? ' (${item.weightGrams!.round()}g)' : '';
      return '$qty x ${item.matchedServingDescription}$weight';
    }
    if (item.requestedQuantity != null && item.requestedUnit != null) {
      return '${item.requestedQuantity} ${item.requestedUnit}';
    }
    if (item.requestedQuantity != null) {
      return 'Quantity: ${item.requestedQuantity}';
    }
    return 'Amount not specified';
  }

  Widget _buildMacroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style: AppTheme.bodySM.copyWith(
          fontSize: 11,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
