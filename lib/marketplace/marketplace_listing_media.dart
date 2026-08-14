import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';

/// Returns the ordered, non-empty listing photo URLs saved by the media service.
List<String> marketplaceListingImageUrls(Map<String, dynamic> listing) {
  final value = listing['imageUrls'];
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// Uses the seller-selected thumbnail when it is still part of the listing.
///
/// Older listings do not have [thumbnailUrl], so their first uploaded photo
/// remains the backwards-compatible thumbnail.
String? marketplaceListingThumbnailUrl(Map<String, dynamic> listing) {
  final images = marketplaceListingImageUrls(listing);
  final selected = '${listing['thumbnailUrl'] ?? ''}'.trim();
  if (selected.isNotEmpty && images.contains(selected)) return selected;
  return images.firstOrNull;
}

/// Premium visual treatment for Marketplace listing photography.
///
/// Real seller photography always wins. Listings without a valid photo use
/// the existing Pipe Buyer industrial illustration library, resolved from the
/// product type/category. This keeps empty cards visually useful without
/// pretending stock artwork is an actual photo of the listed item.
class MarketplaceListingMedia extends StatelessWidget {
  const MarketplaceListingMedia({
    super.key,
    required this.listing,
    this.height = 190,
    this.borderRadius = 16,
    this.fit = BoxFit.cover,
    this.showPhotoCount = true,
    this.showCategoryLabel = false,
    this.heroTag,
  });

  final Map<String, dynamic> listing;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool showPhotoCount;
  final bool showCategoryLabel;
  final Object? heroTag;

  String get _title => '${listing['title'] ?? 'Marketplace listing'}'.trim();
  String get _category => '${listing['category'] ?? ''}'.trim();
  String get _productType => '${listing['productType'] ?? ''}'.trim();
  String get _visualLabel => _productType.isNotEmpty ? _productType : _category;

  @override
  Widget build(BuildContext context) {
    final images = marketplaceListingImageUrls(listing);
    final thumbnail = marketplaceListingThumbnailUrl(listing);
    final visual = thumbnail == null
        ? _IndustrialFallback(
            label: _visualLabel,
            title: _title,
            category: _category,
          )
        : _RemoteListingPhoto(
            url: thumbnail,
            title: _title,
            fallbackLabel: _visualLabel,
            category: _category,
            fit: fit,
          );

    final framed = SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            visual,
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x08000000),
                      Color(0x50000000),
                    ],
                    stops: [0, .58, 1],
                  ),
                ),
              ),
            ),
            if (showPhotoCount && images.length > 1)
              Positioned(
                right: 10,
                top: 10,
                child: _MediaBadge(
                  icon: Icons.photo_library_outlined,
                  label: '${images.length} photos',
                ),
              ),
            if (showCategoryLabel && _category.isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                right: 10,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _MediaBadge(
                    icon: Icons.category_outlined,
                    label: _category,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final content = heroTag == null
        ? framed
        : Hero(
            tag: heroTag!,
            transitionOnUserGestures: true,
            child: framed,
          );

    return Semantics(
      image: true,
      label: thumbnail == null
          ? '$_title. Industrial category illustration; seller photo not provided.'
          : '$_title listing photo',
      child: content,
    );
  }
}

class _RemoteListingPhoto extends StatelessWidget {
  const _RemoteListingPhoto({
    required this.url,
    required this.title,
    required this.fallbackLabel,
    required this.category,
    required this.fit,
  });

  final String url;
  final String title;
  final String fallbackLabel;
  final String category;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        fit: fit,
        filterQuality: FilterQuality.high,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              _IndustrialFallback(
                label: fallbackLabel,
                title: title,
                category: category,
              ),
              const Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ],
          );
        },
        errorBuilder: (_, __, ___) => _IndustrialFallback(
          label: fallbackLabel,
          title: title,
          category: category,
        ),
      );
}

class _IndustrialFallback extends StatelessWidget {
  const _IndustrialFallback({
    required this.label,
    required this.title,
    required this.category,
  });

  final String label;
  final String title;
  final String category;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label.trim().isEmpty ? category : label;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PipeBuyerColors.ink,
            PipeBuyerColors.graphite,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PipeBuyerColors.orange.withValues(alpha: .10),
              ),
            ),
          ),
          Positioned(
            left: -22,
            bottom: -42,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .035),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IndustrialAssetIcon(
                    label: resolvedLabel,
                    size: 104,
                    borderRadius: 12,
                    fallback: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedLabel.isEmpty ? 'Industrial listing' : resolvedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 11,
            bottom: 10,
            child: _MediaBadge(
              icon: Icons.image_not_supported_outlined,
              label: 'Seller photo not provided',
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC111820),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}
