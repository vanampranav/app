import 'package:flutter/material.dart';
import '../../models/ask_ele_recommendation.dart';
import '../../theme/app_theme.dart';

class AskEleMealRecommendationCard extends StatefulWidget {
  final MealRecommendationResponse recommendation;
  final Function(MealRecommendationOption option)? onOptionSelected;
  final Function(String optionId, String action)? onFeedback;
  final VoidCallback? onRefresh;
  final String? selectedOptionId;

  const AskEleMealRecommendationCard({
    super.key,
    required this.recommendation,
    this.onOptionSelected,
    this.onFeedback,
    this.onRefresh,
    this.selectedOptionId,
  });

  @override
  State<AskEleMealRecommendationCard> createState() =>
      _AskEleMealRecommendationCardState();
}

class _AskEleMealRecommendationCardState
    extends State<AskEleMealRecommendationCard> {
  final Set<String> _likedOptionIds = {};
  final Set<String> _dislikedOptionIds = {};

  String _formatMealTypeHeader(String type) {
    final norm = type.toLowerCase().trim();
    if (norm == 'breakfast') return 'Breakfast Ideas';
    if (norm == 'lunch') return 'Lunch Ideas';
    if (norm == 'dinner') return 'Dinner Ideas';
    return 'Snack Ideas';
  }

  void _handleLike(String optionId) {
    setState(() {
      if (_likedOptionIds.contains(optionId)) {
        _likedOptionIds.remove(optionId);
      } else {
        _likedOptionIds.add(optionId);
        _dislikedOptionIds.remove(optionId);
        widget.onFeedback?.call(optionId, 'liked');
      }
    });
  }

  void _handleDislike(String optionId) {
    setState(() {
      if (_dislikedOptionIds.contains(optionId)) {
        _dislikedOptionIds.remove(optionId);
      } else {
        _dislikedOptionIds.add(optionId);
        _likedOptionIds.remove(optionId);
        widget.onFeedback?.call(optionId, 'disliked');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.purple.withValues(alpha: 0.5),
          width: 1,
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
          // ── Header Row ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.lime,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatMealTypeHeader(rec.mealType),
                    style: AppTheme.headingSM.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: widget.onRefresh,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.lime,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: AppTheme.labelSM.copyWith(
                          color: AppTheme.lime,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // ── Options List ───────────────────────────────────────────────────
          ...rec.options.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final option = entry.value;
            final isSelected = widget.selectedOptionId == option.optionId;
            final isLiked = _likedOptionIds.contains(option.optionId);
            final isDisliked = _dislikedOptionIds.contains(option.optionId);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.sm),
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.lime.withValues(alpha: 0.08)
                    : AppTheme.bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.lime
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Option Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Option $idx: ${option.title}',
                          style: AppTheme.headingSM.copyWith(
                            fontSize: 14,
                            color: isSelected
                                ? AppTheme.lime
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lime,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SELECTED',
                            style: AppTheme.labelSM.copyWith(
                              fontSize: 9,
                              color: AppTheme.bg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (option.rationale.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.rationale,
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.xs),

                  // Foods Tag Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: option.foods.map((food) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.purple.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          food,
                          style: AppTheme.bodySM.copyWith(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppTheme.xs),

                  // Macros Estimate Row
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        option.estimatedCalories != null
                            ? '~${option.estimatedCalories} kcal${option.estimatedProtein != null ? ' • ~${option.estimatedProtein}g protein' : ''}'
                            : 'Approximate estimate',
                        style: AppTheme.bodySM.copyWith(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.sm),

                  // Actions Row: Thumbs Up / Down & Choose This
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 18,
                              color: isLiked
                                  ? AppTheme.lime
                                  : AppTheme.textSecondary,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            onPressed: () => _handleLike(option.optionId),
                            tooltip: 'Fits me',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              isDisliked
                                  ? Icons.thumb_down_rounded
                                  : Icons.thumb_down_outlined,
                              size: 18,
                              color: isDisliked
                                  ? Colors.redAccent
                                  : AppTheme.textSecondary,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            onPressed: () => _handleDislike(option.optionId),
                            tooltip: 'Does not fit me',
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => widget.onOptionSelected?.call(option),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected ? AppTheme.lime : AppTheme.purple,
                          foregroundColor:
                              isSelected ? AppTheme.bg : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                        child: Text(
                          isSelected ? 'Selected' : 'Choose this',
                          style: AppTheme.labelSM.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.bg : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
