import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Un conteneur animé reproduisant un effet scintillant (shimmer) natif
/// sans dépendance tierce. Léger, fluide et très économe en batterie.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE5E5E5),
    this.highlightColor = const Color(0xFFF7F7F7),
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              colors: [
                widget.baseColor,
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}

/// Bloc gris de base pour composer un squelette d'UI.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(AppRadius.sm))
            : null,
        shape: shape,
      ),
    );
  }
}

/// Squelette d'une carte d'annonce (PropertyCard).
class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: ShimmerBox(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const ShimmerBox(width: 85, height: 16),
        const SizedBox(height: 6),
        const ShimmerBox(width: 120, height: 12),
        const SizedBox(height: 6),
        const Row(
          children: [
            ShimmerBox(width: 14, height: 14, shape: BoxShape.circle),
            SizedBox(width: 4),
            Expanded(child: ShimmerBox(height: 12)),
          ],
        ),
      ],
    );
  }
}

/// Grille réactive de squelettes de cartes d'annonces.
class PropertyGridSkeleton extends StatelessWidget {
  const PropertyGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      AppSpacing.screenPadding,
      100,
    ),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1024 ? 220.0 : 240.0;
    final availableWidth = screenWidth >= 768 ? (screenWidth - sidebarWidth) : screenWidth;
    final int crossAxisCount;
    final double childAspectRatio;

    if (availableWidth >= 1280) {
      crossAxisCount = 4;
      childAspectRatio = 0.74;
    } else if (availableWidth >= 880) {
      crossAxisCount = 3;
      childAspectRatio = 0.72;
    } else if (availableWidth >= 520) {
      crossAxisCount = 2;
      childAspectRatio = 0.70;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.68;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: ShimmerLoading(
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.lg,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) => const PropertyCardSkeleton(),
          ),
        ),
      ),
    );
  }
}
