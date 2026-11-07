import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_navigation.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_taxonomy.dart';

class PipeBuyerHomeShopShowcase extends StatefulWidget {
  const PipeBuyerHomeShopShowcase({
    super.key,
    this.client,
  });

  final PipeBuyerShopClient? client;

  @override
  State<PipeBuyerHomeShopShowcase> createState() =>
      _PipeBuyerHomeShopShowcaseState();
}

class _PipeBuyerHomeShopShowcaseState extends State<PipeBuyerHomeShopShowcase> {
  late final PipeBuyerShopClient _client;
  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _products =
      PipeBuyerShopClient.mergeWithStarterCatalog(
          const <PipeBuyerShopProduct>[]);
  String _regionCode = 'US';

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _load();
  }

  Future<void> _load() async {
    final region = await _client.loadPreferredRegion();
    final snap = await _client.loadStoreCatalog();
    if (!mounted) return;
    setState(() {
      _regionCode = region;
      _settings = snap.settings;
      _products = snap.products;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_settings.storeEnabled) return const SizedBox.shrink();
    final featured = _products
        .where((p) => p.status == 'active')
        .take(4)
        .toList(growable: false);
    if (featured.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'SHOPPING & PARTNER STORE',
                      style: TextStyle(
                        color: PipeBuyerColors.orangePressed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Shop Tools, Welding, Rigging & Jobsite Gear',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        MarketplaceNavigation.openShopVendorApply(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text(
                      'Vendor / Brand Portal',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        MarketplaceNavigation.openShopStore(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(60, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text(
                      'Visit Store',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PipeBuyerShopTaxonomy.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = PipeBuyerShopTaxonomy.categories[index];
                return ActionChip(
                  avatar: Icon(cat.icon, size: 15, color: cat.accentColor),
                  label: Text(
                    cat.shortLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => MarketplaceNavigation.openShopStore(
                    context,
                    initialCategoryCode: cat.code,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 980
                  ? 4
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              const gap = 10.0;
              final itemWidth =
                  (constraints.maxWidth - (gap * (cols - 1))) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: featured.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _CompactAffiliateTile(
                      product: item,
                      onTap: () => _client.openProductAffiliateLink(
                        product: item,
                        settings: _settings,
                        regionCode: _regionCode,
                        placement: 'home_showcase',
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            _settings.disclosureText,
            style: const TextStyle(
              fontSize: 10.5,
              color: PipeBuyerColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerContextualShopCard extends StatefulWidget {
  const PipeBuyerContextualShopCard({
    super.key,
    required this.marketplaceCategory,
    this.client,
  });

  final String marketplaceCategory;
  final PipeBuyerShopClient? client;

  @override
  State<PipeBuyerContextualShopCard> createState() =>
      _PipeBuyerContextualShopCardState();
}

class _PipeBuyerContextualShopCardState
    extends State<PipeBuyerContextualShopCard> {
  late final PipeBuyerShopClient _client;
  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _catalog =
      PipeBuyerShopClient.mergeWithStarterCatalog(
          const <PipeBuyerShopProduct>[]);
  String _regionCode = 'US';

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _load();
  }

  Future<void> _load() async {
    final region = await _client.loadPreferredRegion();
    final snap = await _client.loadStoreCatalog();
    if (!mounted) return;
    setState(() {
      _regionCode = region;
      _settings = snap.settings;
      _catalog = snap.products;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_settings.storeEnabled) return const SizedBox.shrink();
    final shopCat = PipeBuyerShopTaxonomy.categoryForMarketplaceCategory(
      widget.marketplaceCategory,
    );
    final items = PipeBuyerShopTaxonomy.contextualProductsForMarketplace(
      widget.marketplaceCategory,
      catalog: _catalog,
      limit: 2,
    );
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 18,
                color: PipeBuyerColors.orangePressed,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Recommended ${shopCat.shortLabel} Gear',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => MarketplaceNavigation.openShopStore(
                  context,
                  initialCategoryCode: shopCat.code,
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Open Store',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => _client.openProductAffiliateLink(
                  product: item,
                  settings: _settings,
                  regionCode: _regionCode,
                  placement: 'listing_contextual',
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: PipeBuyerColors.line),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: item.imageUrl.trim().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CachedNetworkImage(
                                  imageUrl: item.imageUrl.trim(),
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => SvgPicture.asset(
                                    item.effectiveIconAsset,
                                    fit: BoxFit.contain,
                                  ),
                                  errorWidget: (_, __, ___) => SvgPicture.asset(
                                    item.effectiveIconAsset,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            : SvgPicture.asset(
                                item.effectiveIconAsset,
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => Icon(
                                  item.category.icon,
                                  size: 20,
                                  color: PipeBuyerColors.orange,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${item.brand} • ${item.effectiveCtaLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: PipeBuyerColors.orangePressed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: PipeBuyerColors.slate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Affiliate Partner Links • Pipe Buyer earns from qualifying Amazon & partner purchases.',
            style: TextStyle(fontSize: 10, color: PipeBuyerColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CompactAffiliateTile extends StatelessWidget {
  const _CompactAffiliateTile({
    required this.product,
    required this.onTap,
  });

  final PipeBuyerShopProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PipeBuyerColors.surfaceMuted,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: product.imageUrl.trim().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ColoredBox(
                              color: Colors.white,
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl.trim(),
                                fit: BoxFit.contain,
                                placeholder: (_, __) => SvgPicture.asset(
                                  product.effectiveIconAsset,
                                  fit: BoxFit.contain,
                                ),
                                errorWidget: (_, __, ___) => SvgPicture.asset(
                                  product.effectiveIconAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        : SvgPicture.asset(
                            product.effectiveIconAsset,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) => Icon(
                              product.category.icon,
                              size: 20,
                              color: product.category.accentColor,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.orangePressed,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 15,
                    color: PipeBuyerColors.slate,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.effectiveCtaLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: PipeBuyerColors.industrialBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
