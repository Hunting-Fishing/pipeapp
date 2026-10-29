import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'pipe_buyer_theme.dart';

export 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'
    show AlignedGridView;
export 'package:gap/gap.dart' show Gap;
export 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;
export 'package:skeletonizer/skeletonizer.dart' show Skeletonizer, BoneMock;

/// Reusable 2026 interactive card container with desktop hover elevation,
/// safety-orange border transition, cursor affordance, and tactile mobile press.
class PipeBuyerInteractiveCard extends StatefulWidget {
  const PipeBuyerInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.borderColor = const Color(0xFFE2E8F0),
    this.hoverBorderColor = PipeBuyerColors.orange,
    this.borderWidth = 1.0,
    this.emphasizedShadowColor,
    this.backgroundColor = Colors.white,
    this.enableHoverLift = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color borderColor;
  final Color hoverBorderColor;
  final double borderWidth;
  final Color? emphasizedShadowColor;
  final Color backgroundColor;
  final bool enableHoverLift;

  @override
  State<PipeBuyerInteractiveCard> createState() =>
      _PipeBuyerInteractiveCardState();
}

class _PipeBuyerInteractiveCardState extends State<PipeBuyerInteractiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final activeHover = widget.enableHoverLift && _hovered;
    final dy = _pressed ? 0.0 : (activeHover ? -3.0 : 0.0);
    final scale = _pressed ? 0.992 : 1.0;
    final effectiveBorder =
        activeHover ? widget.hoverBorderColor : widget.borderColor;
    final effectiveWidth = activeHover
        ? (widget.borderWidth < 1.5 ? 1.5 : widget.borderWidth)
        : widget.borderWidth;

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, dy, 0),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: effectiveBorder,
                width: effectiveWidth,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.emphasizedShadowColor ??
                      (activeHover
                          ? const Color(0x1F0F172A)
                          : const Color(0x0D0F172A)),
                  blurRadius: activeHover ? 24 : 14,
                  offset: Offset(0, activeHover ? 10 : 4),
                ),
                if (activeHover)
                  BoxShadow(
                    color: PipeBuyerColors.orange.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (v) {
                  if (_pressed != v) setState(() => _pressed = v);
                },
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight desktop hover wrapper: lifts any existing card `3px` with a
/// smooth ease-out transition and pointer cursor, without altering its own
/// tap handling, borders, or shadows.
class PipeBuyerHoverLift extends StatefulWidget {
  const PipeBuyerHoverLift({super.key, required this.child});

  final Widget child;

  @override
  State<PipeBuyerHoverLift> createState() => _PipeBuyerHoverLiftState();
}

class _PipeBuyerHoverLiftState extends State<PipeBuyerHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Disk- and memory-cached network image wrapper with smooth shimmer loading
/// and studio-grade fallback artwork.
class PipeBuyerCachedImage extends StatelessWidget {
  const PipeBuyerCachedImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? imageUrl;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final trimmed = (imageUrl ?? '').trim();
    if (trimmed.isEmpty ||
        (!trimmed.startsWith('https://') && !trimmed.startsWith('http://'))) {
      return fallback;
    }

    return CachedNetworkImage(
      imageUrl: trimmed,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 160),
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              PipeBuyerColors.studioSlateTop,
              PipeBuyerColors.studioSlate,
              PipeBuyerColors.studioSlateDeep,
            ],
          ),
        ),
      ),
      errorWidget: (context, _, __) => fallback,
    );
  }
}

/// Compact technical spec pill strip (`4-1/2" OD`, `E-75`, `4,380 hrs`, etc.)
/// formatted with tabular numerals for rapid B2B spec scanning.
class PipeBuyerSpecPillStrip extends StatelessWidget {
  const PipeBuyerSpecPillStrip({
    super.key,
    required this.specs,
    this.maxPills = 3,
  });

  final List<String> specs;
  final int maxPills;

  @override
  Widget build(BuildContext context) {
    final cleaned = specs
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxPills)
        .toList(growable: false);
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: cleaned
          .map(
            (spec) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                spec,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PipeBuyerTypography.tabularSpec(fontSize: 10.6),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Shimmer skeleton loading grid powered by `skeletonizer` + `AlignedGridView`,
/// replacing bare `CircularProgressIndicator` spinners on Home & Browse feeds.
class PipeBuyerListingSkeletonGrid extends StatelessWidget {
  const PipeBuyerListingSkeletonGrid({
    super.key,
    this.count = 4,
    this.crossAxisCount,
    this.shrinkWrap = true,
    this.padding = EdgeInsets.zero,
  });

  final int count;
  final int? crossAxisCount;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = crossAxisCount ??
            (constraints.maxWidth >= 1040
                ? 4
                : constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 360
                        ? 2
                        : 1);
        return ExcludeSemantics(
            child: Skeletonizer(
          enabled: true,
          child: AlignedGridView.count(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: shrinkWrap,
            padding: padding,
            physics: shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: count,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1.34,
                    child: Container(color: const Color(0xFFE2E8F0)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        Text(
                          'CATEGORY NAME • CITY, ST',
                          style: TextStyle(fontSize: 10),
                        ),
                        Gap(6),
                        Text(
                          'Listing title loading here',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Gap(8),
                        Text(
                          'Spec • Spec • Spec',
                          style: TextStyle(fontSize: 11),
                        ),
                        Gap(12),
                        Text(
                          '\$00,000',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }
}

/// Adaptive 2026 modal launcher powered by `wolt_modal_sheet`:
/// opens a centered `600px` dialog on Desktop Web (`>=760px`) and a smooth
/// draggable modal sheet on Mobile (`<760px`).
abstract final class PipeBuyerAdaptiveModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget Function(BuildContext modalContext) builder,
  }) {
    return WoltModalSheet.show<T>(
      context: context,
      modalTypeBuilder: (ctx) {
        final width = MediaQuery.sizeOf(ctx).width;
        return width >= 760
            ? WoltModalType.dialog()
            : WoltModalType.bottomSheet();
      },
      pageListBuilder: (modalContext) => <SliverWoltModalSheetPage>[
        WoltModalSheetPage(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          hasTopBarLayer: true,
          isTopBarLayerAlwaysVisible: true,
          topBarTitle: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: PipeBuyerColors.ink,
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PipeBuyerColors.muted,
                  ),
                ),
            ],
          ),
          trailingNavBarWidget: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(modalContext).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: builder(modalContext),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen HD pinch-to-zoom & scroll-wheel-zoom inspection lightbox
/// powered by `photo_view` + `smooth_page_indicator`.
class PipeBuyerPhotoLightbox extends StatefulWidget {
  const PipeBuyerPhotoLightbox({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.title,
  });

  final List<String> photos;
  final int initialIndex;
  final String title;

  static Future<void> open(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
    required String title,
  }) {
    if (photos.isEmpty) return Future<void>.value();
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0xEB090E17),
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: PipeBuyerPhotoLightbox(
            photos: photos,
            initialIndex: initialIndex,
            title: title,
          ),
        ),
      ),
    );
  }

  @override
  State<PipeBuyerPhotoLightbox> createState() => _PipeBuyerPhotoLightboxState();
}

class _PipeBuyerPhotoLightboxState extends State<PipeBuyerPhotoLightbox> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF2080D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${_current + 1} / ${widget.photos.length}',
                style: PipeBuyerTypography.tabularSpec(
                  fontSize: 12.5,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close viewer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _current = index),
            backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(widget.photos[index]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.5,
              heroAttributes: PhotoViewHeroAttributes(
                tag: 'listing_photo_${widget.photos[index]}_$index',
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.photos.length,
                  effect: const ExpandingDotsEffect(
                    dotHeight: 7,
                    dotWidth: 7,
                    expansionFactor: 3,
                    spacing: 6,
                    activeDotColor: PipeBuyerColors.orange,
                    dotColor: Colors.white38,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
