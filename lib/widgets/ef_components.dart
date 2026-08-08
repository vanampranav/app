import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── ELEFIT Component Library ─────────────────────────────────────────────────
// Reusable, brand-consistent widgets for the EleFit fitness app.

// ── EFButton ──────────────────────────────────────────────────────────────────
enum EFButtonVariant { primary, secondary, ghost, danger }

class EFButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final EFButtonVariant variant;
  final Widget? icon;
  final bool loading;
  final bool fullWidth;
  final double? height;
  final EdgeInsets? padding;

  const EFButton({
    Key? key,
    required this.label,
    this.onTap,
    this.variant = EFButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  State<EFButton> createState() => _EFButtonState();
}

class _EFButtonState extends State<EFButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _bg {
    switch (widget.variant) {
      case EFButtonVariant.primary:   return AppTheme.lime;
      case EFButtonVariant.secondary: return AppTheme.purple;
      case EFButtonVariant.ghost:     return Colors.transparent;
      case EFButtonVariant.danger:    return AppTheme.error;
    }
  }

  Color get _fg {
    switch (widget.variant) {
      case EFButtonVariant.primary: return Colors.black;
      default:                      return Colors.white;
    }
  }

  Border? get _border {
    if (widget.variant == EFButtonVariant.ghost) {
      return Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height ?? 52,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: _border,
            boxShadow: widget.variant == EFButtonVariant.primary && widget.onTap != null
                ? AppTheme.shadowLime
                : null,
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        IconTheme(data: IconThemeData(color: _fg, size: 18), child: widget.icon!),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label.toUpperCase(),
                        style: AppTheme.labelLG.copyWith(
                          color: _fg,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── EFCard ────────────────────────────────────────────────────────────────────
class EFCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final VoidCallback? onTap;
  final bool elevated;
  final bool hasBorder;
  final BorderRadius? borderRadius;

  const EFCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.elevated = false,
    this.hasBorder = true,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppTheme.radiusXl);
    final cardColor = color ?? (elevated ? AppTheme.surface2 : AppTheme.surface1);

    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: br,
        border: hasBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1)
            : null,
        boxShadow: elevated ? AppTheme.shadowMd : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

// ── EFGlassCard ───────────────────────────────────────────────────────────────
class EFGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? tintColor;
  final BorderRadius? borderRadius;

  const EFGlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.tintColor,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: (tintColor ?? Colors.white).withValues(alpha: 0.05),
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: (tintColor ?? Colors.white).withValues(alpha: 0.12),
        ),
      ),
      child: child,
    );
  }
}

// ── EFProgressRing ────────────────────────────────────────────────────────────
// Animated circular progress ring — used for daily calorie display.
class EFProgressRing extends StatefulWidget {
  final double progress;       // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;
  final Widget? center;
  final bool animate;

  const EFProgressRing({
    Key? key,
    required this.progress,
    this.size = 180,
    this.strokeWidth = 12,
    this.progressColor = AppTheme.lime,
    this.trackColor = AppTheme.surface3,
    this.center,
    this.animate = true,
  }) : super(key: key);

  @override
  State<EFProgressRing> createState() => _EFProgressRingState();
}

class _EFProgressRingState extends State<EFProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.progress.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    if (widget.animate) _ctrl.forward();
  }

  @override
  void didUpdateWidget(EFProgressRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress.clamp(0.0, 1.0))
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(
            progress: _anim.value,
            strokeWidth: widget.strokeWidth,
            progressColor: widget.progressColor,
            trackColor: widget.trackColor,
          ),
          child: widget.center != null
              ? Center(child: widget.center)
              : null,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, 2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Gradient progress arc
      final sweepAngle = 2 * math.pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [progressColor, progressColor.withValues(alpha: 0.7)],
      ).createShader(rect);

      canvas.drawArc(
        rect,
        -math.pi / 2, sweepAngle,
        false,
        Paint()
          ..shader = gradient
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Glow dot at the tip
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        strokeWidth / 2,
        Paint()
          ..color = progressColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(tipX, tipY),
        strokeWidth / 2,
        Paint()..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.progressColor != progressColor;
}

// ── EFMacroBar ────────────────────────────────────────────────────────────────
class EFMacroBar extends StatefulWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  final String unit;

  const EFMacroBar({
    Key? key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.unit = 'g',
  }) : super(key: key);

  @override
  State<EFMacroBar> createState() => _EFMacroBarState();
}

class _EFMacroBarState extends State<EFMacroBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: _progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  // Re-animate when current or target values change (e.g. loaded async from prefs)
  @override
  void didUpdateWidget(EFMacroBar old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current || old.target != widget.target) {
      _anim = Tween<double>(begin: _anim.value, end: _progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl.forward(from: 0);
    }
  }

  double get _progress => widget.target > 0
      ? (widget.current / widget.target).clamp(0.0, 1.0)
      : 0.0;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: AppTheme.labelMD),
            Text(
              '${widget.current}/${widget.target}${widget.unit}',
              // Turn red once the macro goal is exceeded, for a clear over-goal cue.
              style: AppTheme.labelMD.copyWith(
                color: widget.current > widget.target ? AppTheme.error : widget.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Stack(
              children: [
                Container(height: 6, color: AppTheme.surface3),
                FractionallySizedBox(
                  widthFactor: _anim.value,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      boxShadow: [
                        BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── EFAnimatedEntry ───────────────────────────────────────────────────────────
/// Fades + slides a child in after [delay]. Use for staggered list items.
class EFAnimatedEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const EFAnimatedEntry({
    Key? key,
    required this.child,
    this.delay   = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
  }) : super(key: key);

  @override
  State<EFAnimatedEntry> createState() => _EFAnimatedEntryState();
}

class _EFAnimatedEntryState extends State<EFAnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── EFStatTile ────────────────────────────────────────────────────────────────
class EFStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final Widget? icon;
  final VoidCallback? onTap;

  const EFStatTile({
    Key? key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: EFCard(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(), style: AppTheme.labelSM),
                if (icon != null)
                  IconTheme(
                    data: IconThemeData(color: valueColor ?? AppTheme.lime, size: 16),
                    child: icon!,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppTheme.numericMD.copyWith(color: valueColor ?? AppTheme.textPrimary),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(unit!, style: AppTheme.bodyMD),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── EFSectionHeader ───────────────────────────────────────────────────────────
class EFSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const EFSectionHeader({
    Key? key,
    required this.title,
    this.action,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title.toUpperCase(), style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(action!, style: AppTheme.labelMD.copyWith(color: AppTheme.lime)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, color: AppTheme.lime, size: 14),
              ],
            ),
          ),
      ],
    );
  }
}

// ── EFStreakBadge ─────────────────────────────────────────────────────────────
class EFStreakBadge extends StatelessWidget {
  final int streak;
  final bool compact;

  const EFStreakBadge({Key? key, required this.streak, this.compact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppTheme.sm : AppTheme.md,
        vertical: compact ? 4 : AppTheme.sm,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF4757)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: compact ? 12 : 14)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppTheme.labelLG.copyWith(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── EFQuickAction ─────────────────────────────────────────────────────────────
class EFQuickAction extends StatefulWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final Color? accentColor;

  const EFQuickAction({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
  }) : super(key: key);

  @override
  State<EFQuickAction> createState() => _EFQuickActionState();
}

class _EFQuickActionState extends State<EFQuickAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppTheme.lime;

    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _ctrl.reverse();
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _ctrl.reverse();
        setState(() => _pressed = false);
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
          decoration: BoxDecoration(
            // Gradient background — stronger on press
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(_pressed ? 0.22 : 0.13),
                color.withOpacity(_pressed ? 0.08 : 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: color.withOpacity(_pressed ? 0.55 : 0.28),
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [
                    BoxShadow(
                      color: color.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon inside an accent-coloured circle with gradient + glow
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.72)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_pressed ? 0.55 : 0.38),
                      blurRadius: _pressed ? 14 : 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.black87, size: 22),
              ),
              const SizedBox(height: 11),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── EFDivider ─────────────────────────────────────────────────────────────────
class EFDivider extends StatelessWidget {
  final EdgeInsets? margin;
  const EFDivider({Key? key, this.margin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppTheme.md),
      height: 1,
      color: AppTheme.divider,
    );
  }
}

// ── EFShimmer ─────────────────────────────────────────────────────────────────
class EFShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const EFShimmer({
    Key? key,
    required this.width,
    required this.height,
    this.radius = AppTheme.radiusMd,
  }) : super(key: key);

  @override
  State<EFShimmer> createState() => _EFShimmerState();
}

class _EFShimmerState extends State<EFShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.03, end: 0.1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── EFTag ─────────────────────────────────────────────────────────────────────
class EFTag extends StatelessWidget {
  final String label;
  final Color? color;

  const EFTag({Key? key, required this.label, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.lime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label.toUpperCase(), style: AppTheme.labelSM.copyWith(color: c)),
    );
  }
}

// ── EFNavBar (premium animated bottom nav) ────────────────────────────────────
class EFNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int cartCount;

  const EFNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.cartCount = 0,
  }) : super(key: key);

  static const _items = [
    _NavItem(icon: Icons.home_outlined,              activeIcon: Icons.home_rounded,              label: 'Home'),
    _NavItem(icon: Icons.restaurant_menu_outlined,   activeIcon: Icons.restaurant_menu_rounded,   label: 'Nutrition'),
    _NavItem(icon: Icons.storefront_outlined,        activeIcon: Icons.storefront_rounded,        label: 'Shop'),
    _NavItem(icon: Icons.insights_outlined,           activeIcon: Icons.insights,                  label: 'Performance'),
    _NavItem(icon: Icons.person_outline,             activeIcon: Icons.person_rounded,            label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) => _buildItem(context, i)),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i) {
    final active = selectedIndex == i;
    final item = _items[i];

    final Widget iconWidget = Icon(
      active ? item.activeIcon : item.icon,
      size: 24,
      color: active ? AppTheme.lime : AppTheme.textTertiary,
    );

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onItemSelected(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTheme.labelSM.copyWith(
                color: active ? AppTheme.lime : AppTheme.textTertiary,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: active ? 18 : 0,
              decoration: BoxDecoration(
                color: AppTheme.lime,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active ? AppTheme.shadowLime : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ── Page route with slide transition ─────────────────────────────────────────
class EFPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  EFPageRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 280),
        );
}
