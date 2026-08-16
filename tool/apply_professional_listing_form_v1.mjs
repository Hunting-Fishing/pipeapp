import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const relative = 'lib/marketplace/oil_gas_marketplace.dart';
const target = path.join(root, relative);
if (!fs.existsSync(target)) throw new Error(`Missing ${relative}`);

let source = fs.readFileSync(target, 'utf8');

function requiredReplace(before, after, label) {
  if (source.includes(after)) return;
  if (!source.includes(before)) {
    throw new Error(`Professional listing form migration could not find: ${label}`);
  }
  source = source.replace(before, after);
}

function optionalReplace(before, after) {
  if (source.includes(before)) source = source.replaceAll(before, after);
}

const presentationImport = "import 'marketplace_listing_form_presentation.dart';";
if (!source.includes(presentationImport)) {
  const importAnchor = "import 'marketplace_listing_media.dart';";
  if (!source.includes(importAnchor)) {
    throw new Error('Could not locate marketplace_listing_media.dart import.');
  }
  source = source.replace(importAnchor, `${importAnchor}\n${presentationImport}`);
}

// Public language only. Internal transactionType='Auction' and callable names
// remain unchanged for compatibility with the existing Firebase command model.
optionalReplace("'Timed auctions'", "'Timed Buying'");
optionalReplace("'Timed auction'", "'Timed Buying'");
optionalReplace(
  "'Sell, auction or post a wanted ad'",
  "'Sell, use Timed Buying, or post a wanted ad'",
);
optionalReplace(
  "'Live bids, reserve pricing and history'",
  "'Timed offers, closing times and offer history'",
);
optionalReplace("'View auctions'", "'View Timed Buying'");
optionalReplace("'Publish timed auction'", "'Publish Timed Buying'");
optionalReplace(
  "'Auction listings require a User Score above 80, 100% profile completion, and verified account status.'",
  "'Timed Buying listings require a User Score above 80, 100% profile completion, and verified account status.'",
);
optionalReplace(
  "'Choose a valid auction start and end time. The end must be after the start.'",
  "'Choose a valid Timed Buying start and closing time. The close must be after the start.'",
);
optionalReplace(
  "'Listing published successfully, but the preview could not open. View it from My Listings or Auctions.'",
  "'Listing published successfully, but the preview could not open. View it from My Listings or Timed Buying.'",
);

// Keep the internal Auction value but present a clear customer-facing
// destination label everywhere in the create-listing header.
requiredReplace(
  "    if (_isAuction) return 'Auction';",
  "    if (_isAuction) return 'Timed Buying';",
  'Timed Buying placement label',
);

const headerPattern = /  Widget _listingHeader\(User user\) \{[\s\S]*?\n  Widget _wantedSetupCard\(\)/;
const newHeader = `  Widget _listingHeader(User user) {
    final icon = _isAuction
        ? Icons.timer_outlined
        : _isWanted
            ? Icons.campaign_outlined
            : Icons.storefront_outlined;
    final accent = _isWanted
        ? const Color(0xFF7557D3)
        : _isAuction
            ? const Color(0xFFF08A24)
            : _orange;
    final description = _isWanted
        ? 'Tell suppliers exactly what you need, acceptable condition, quantity and delivery area.'
        : _isAuction
            ? 'Publish the same professional asset details, then set the opening offer and closing schedule.'
            : 'Build a structured listing that buyers can compare quickly on desktop or mobile.';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create listing',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Listing as \${user.email ?? 'your marketplace account'}',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
      ]),
      const SizedBox(height: 14),
      const Text(
        'WHERE SHOULD THIS APPEAR?',
        style: TextStyle(
          color: _muted,
          fontSize: 9.5,
          letterSpacing: .45,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 7),
      MarketplaceListingPlacementSelector(
        selected: _placement,
        timedBuyingEnabled: widget.auctionsEnabled,
        wantedEnabled: widget.wantedAdsEnabled,
        onChanged: (placement) => _setPlacement(
          placement == 'Timed Buying' ? 'Auction' : placement,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _wantedSetupCard()`;

if (!source.includes('WHERE SHOULD THIS APPEAR?')) {
  if (!headerPattern.test(source)) {
    throw new Error('Could not isolate _listingHeader for safe replacement.');
  }
  source = source.replace(headerPattern, newHeader);
}

// Broaden the existing structured equipment fields to other powered industrial
// asset categories. Heavy Equipment still requires year/make/model; the other
// categories receive the same fields as optional structured facts.
requiredReplace(
  "    final isMachine = _category == 'Heavy Equipment';\n    final isProperty = _isProperty;",
  "    final isMachine = _category == 'Heavy Equipment';\n    final isDetailedAsset = const {\n      'Heavy Equipment',\n      'Transport & Hauling',\n      'Oil & Gas Equipment',\n      'Oilfield & Drilling',\n      'Site Support',\n    }.contains(_category);\n    final isProperty = _isProperty;",
  'category-aware detailed asset flag in form',
);

requiredReplace(
  "            if (isMachine) ...[\n              DropdownButtonFormField<int>(",
  "            if (isDetailedAsset) ...[\n              DropdownButtonFormField<int>(",
  'expanded structured asset detail block',
);

requiredReplace(
  "                decoration: const InputDecoration(\n                    labelText: 'Model year *',\n                    prefixIcon: Icon(Icons.calendar_today_outlined)),",
  "                decoration: InputDecoration(\n                    labelText: isMachine ? 'Model year *' : 'Year (optional)',\n                    prefixIcon: const Icon(Icons.calendar_today_outlined)),",
  'category-aware model year label',
);

requiredReplace(
  "                decoration: const InputDecoration(\n                    labelText: 'Machine hours',\n                    suffixText: 'hours',\n                    prefixIcon: Icon(Icons.schedule)),",
  "                decoration: InputDecoration(\n                    labelText: isMachine\n                        ? 'Machine hours'\n                        : 'Runtime / hours (optional)',\n                    suffixText: 'hours',\n                    prefixIcon: const Icon(Icons.schedule)),",
  'category-aware runtime label',
);

optionalReplace(
  "labelText: 'Serial number / PIN (optional)'",
  "labelText: 'Serial / VIN / PIN (optional)'",
);
optionalReplace(
  "labelText: 'Engine / powertrain details'",
  "labelText: 'Engine / power / drive details'",
);
optionalReplace(
  "labelText: 'Attachments and included equipment'",
  "labelText: 'Attachments / included equipment'",
);

// Add lightweight section hierarchy without turning the long industrial form
// into a multi-screen wizard. Users can scan the page and still scroll straight
// through when entering inventory quickly.
requiredReplace(
  "          child: Column(children: [\n            TextFormField(\n              controller: _title,",
  "          child: Column(children: [\n            const MarketplaceListingFormSectionHeader(\n              step: 1,\n              title: 'Item identity',\n              description: 'Start with the title, category and product type buyers will search for.',\n              icon: Icons.inventory_2_outlined,\n            ),\n            TextFormField(\n              controller: _title,\n              onChanged: (_) => setState(() {}),",
  'item identity section',
);

const propertyAnchor = "            const SizedBox(height: 12),\n            if (isProperty) ...[";
if (!source.includes("title: 'Asset specifications'")) {
  const index = source.indexOf(propertyAnchor);
  if (index < 0) throw new Error('Could not locate asset specification section anchor.');
  source = source.slice(0, index) +
    `            const SizedBox(height: 10),\n            MarketplaceListingCategoryGuide(\n              category: _category,\n              productType: _productType,\n            ),\n            const SizedBox(height: 12),\n            const MarketplaceListingFormSectionHeader(\n              step: 2,\n              title: 'Asset specifications',\n              description: 'Use structured facts for comparison; keep long notes for the description.',\n              icon: Icons.tune_rounded,\n            ),\n` +
    source.slice(index + "            const SizedBox(height: 12),\n".length);
}

if (!source.includes("title: 'Condition & inspection'")) {
  const conditionAnchor = "            DropdownButtonFormField<String>(\n              key: ValueKey(\n                  'condition-";
  const index = source.indexOf(conditionAnchor);
  if (index < 0) throw new Error('Could not locate condition section anchor.');
  source = source.slice(0, index) +
    `            const MarketplaceListingFormSectionHeader(\n              step: 3,\n              title: 'Condition & inspection',\n              description: 'State condition clearly and disclose the inspection level buyers can rely on.',\n              icon: Icons.fact_check_outlined,\n            ),\n` +
    source.slice(index);
}

if (!source.includes("title: 'Listing terms'")) {
  const termsAnchor = "            if (!_isAuction && !isWanted)\n              DropdownButtonFormField<String>(";
  const index = source.indexOf(termsAnchor);
  if (index < 0) throw new Error('Could not locate listing terms section anchor.');
  source = source.slice(0, index) +
    `            const MarketplaceListingFormSectionHeader(\n              step: 4,\n              title: 'Listing terms',\n              description: _isAuction\n                  ? 'Set the Timed Buying window, opening offer and optional seller protections.'\n                  : isWanted\n                      ? 'Set budget guidance for suppliers.'\n                      : 'Set price basis and whether buyers can send offers.',\n              icon: Icons.payments_outlined,\n            ),\n` +
    source.slice(index);
}

// Make checklist status react to the few free-text fields that determine core
// readiness. Dropdown/location changes already trigger setState.
requiredReplace(
  "              controller: _quantity,\n                keyboardType: TextInputType.number,",
  "              controller: _quantity,\n                onChanged: (_) => setState(() {}),\n                keyboardType: TextInputType.number,",
  'quantity readiness listener',
);
requiredReplace(
  "              controller: _price,\n              keyboardType:",
  "              controller: _price,\n              onChanged: (_) => setState(() {}),\n              keyboardType:",
  'price readiness listener',
);

// Public Timed Buying pricing language; data keys remain startingBid,
// minimumBidIncrement and reservePrice for backend compatibility.
optionalReplace("'Starting bid (CAD) *'", "'Opening timed offer (CAD) *'");
optionalReplace("'Required starting bid'", "'Required opening offer'");
optionalReplace("'Enter a starting bid'", "'Enter an opening timed offer'");

if (!source.includes("title: 'Location & description'")) {
  const descriptionAnchor = "            TextFormField(\n              controller: _description,\n              minLines: 4,";
  const index = source.indexOf(descriptionAnchor);
  if (index < 0) throw new Error('Could not locate description section anchor.');
  source = source.slice(0, index) +
    `            const MarketplaceListingFormSectionHeader(\n              step: 5,\n              title: 'Location & description',\n              description: 'Keep the public location useful while controlling exact-site privacy.',\n              icon: Icons.location_on_outlined,\n            ),\n` +
    source.slice(index);
}

requiredReplace(
  "              controller: _description,\n              minLines: 4,",
  "              controller: _description,\n              onChanged: (_) => setState(() {}),\n              minLines: 4,",
  'description readiness listener',
);

if (!source.includes("title: 'Photos & video'")) {
  const mediaAnchor = "            Card(\n              margin: EdgeInsets.zero,\n              child: Padding(\n                padding: const EdgeInsets.all(14),\n                child: Column(children: [\n                  Row(children: [\n                    const Icon(Icons.photo_library_outlined),";
  const index = source.indexOf(mediaAnchor);
  if (index < 0) throw new Error('Could not locate media section anchor.');
  source = source.slice(0, index) +
    `            const MarketplaceListingFormSectionHeader(\n              step: 6,\n              title: 'Photos & video',\n              description: 'Use clear overall, identification-plate and condition photos; choose the strongest thumbnail.',\n              icon: Icons.photo_library_outlined,\n            ),\n` +
    source.slice(index);
}

// Core readiness values are calculated inside build so the final review card can
// communicate what is still missing before the user presses Publish.
requiredReplace(
  "    final conditionOptions = marketplaceConditionsFor(_category, _productType);\n    final isWanted = _isWanted;\n    return ListView(",
  "    final conditionOptions = marketplaceConditionsFor(_category, _productType);\n    final isWanted = _isWanted;\n    final identityReady = _title.text.trim().isNotEmpty &&\n        _category != null &&\n        _productType != null;\n    final specificationsReady = _condition != null &&\n        (isProperty || _quantity.text.trim().isNotEmpty) &&\n        (!isPipe || _pipeSize != null) &&\n        (!isMachine ||\n            (_equipmentBrand != null &&\n                _equipmentModel != null &&\n                _equipmentYear != null));\n    final locationReady =\n        _location != null && _description.text.trim().isNotEmpty;\n    final termsReady = !_isAuction ||\n        (_auctionStartAt != null &&\n            _auctionEndAt != null &&\n            _auctionEndAt!.isAfter(_auctionStartAt!) &&\n            (marketplaceMoneyValue(_price.text) ?? 0) > 0 &&\n            (marketplaceMoneyValue(_minimumBidIncrement.text) ?? 0) > 0);\n    return ListView(",
  'listing publish readiness values',
);

if (!source.includes("title: 'Review & publish'")) {
  const publishAnchor = "            const SizedBox(height: 18),\n            FilledButton.icon(\n              onPressed: _publishing ? null : _publish,";
  const index = source.indexOf(publishAnchor);
  if (index < 0) throw new Error('Could not locate publish section anchor.');
  const publishBlock = `            const MarketplaceListingFormSectionHeader(\n              step: 7,\n              title: 'Review & publish',\n              description: 'Confirm the core facts below. You can edit the listing later from your seller account.',\n              icon: Icons.verified_outlined,\n            ),\n            MarketplaceListingPublishChecklist(\n              destinationLabel: _isAuction\n                  ? 'Timed Buying'\n                  : isWanted\n                      ? 'Wanted Ad'\n                      : 'Marketplace',\n              items: [\n                MarketplaceListingChecklistItem(\n                  label: 'Identity',\n                  complete: identityReady,\n                ),\n                MarketplaceListingChecklistItem(\n                  label: 'Specifications',\n                  complete: specificationsReady,\n                ),\n                MarketplaceListingChecklistItem(\n                  label: 'Location & description',\n                  complete: locationReady,\n                ),\n                MarketplaceListingChecklistItem(\n                  label: 'Terms',\n                  complete: termsReady,\n                ),\n              ],\n            ),\n            const SizedBox(height: 12),\n            FilledButton.icon(\n              onPressed: _publishing ? null : _publish,`;
  source = source.slice(0, index) + publishBlock + source.slice(index + publishAnchor.length);
}

// Rebuild the Timed Buying terms panel with compact responsive fields and quick
// duration presets. This changes presentation only; existing date pickers and
// controllers continue to feed the same backend fields.
const timedTermsReplacement = `  Widget _auctionSetupCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFF2D5A8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFFFE5C2),
              child: Icon(Icons.timer_outlined,
                  color: Color(0xFFF08A24), size: 19),
            ),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timed Buying terms',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    'Set when timed offers open and close. The opening offer is entered in the price field below.',
                    style: TextStyle(fontSize: 10.5, color: _muted),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 11),
          MarketplaceListingResponsiveFields(
            children: [
              _timedBuyingDateTile(
                label: 'Offers open',
                value: _auctionStartAt,
                icon: Icons.play_circle_outline,
                onTap: () => _pickAuctionDate(start: true),
              ),
              _timedBuyingDateTile(
                label: 'Closes',
                value: _auctionEndAt,
                icon: Icons.flag_outlined,
                onTap: () => _pickAuctionDate(start: false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('QUICK DURATION',
              style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .35)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final preset in const [
              ('1 day', Duration(days: 1)),
              ('3 days', Duration(days: 3)),
              ('7 days', Duration(days: 7)),
              ('14 days', Duration(days: 14)),
              ('30 days', Duration(days: 30)),
            ])
              ActionChip(
                avatar: const Icon(Icons.schedule_outlined, size: 15),
                label: Text(preset.$1),
                onPressed: () => _setTimedBuyingDuration(preset.$2),
              ),
          ]),
          const SizedBox(height: 10),
          MarketplaceListingResponsiveFields(
            children: [
              TextFormField(
                controller: _minimumBidIncrement,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MarketplaceMoneyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Minimum offer increase (CAD) *',
                  prefixIcon: Icon(Icons.trending_up),
                ),
                validator: (value) {
                  final amount = num.tryParse(
                    value?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
                  );
                  return amount == null || amount <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                },
              ),
              TextFormField(
                controller: _reservePrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MarketplaceMoneyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Seller minimum (optional)',
                  helperText: 'Private seller threshold for standard close.',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _buyItNowPrice,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MarketplaceMoneyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Buy It Now price (optional)',
              helperText:
                  'Allows an eligible buyer to purchase immediately and close the Timed Buying listing.',
              prefixIcon: Icon(Icons.flash_on_outlined),
            ),
          ),
        ]),
      );

  Widget _timedBuyingDateTile({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
  }) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE5D8C4)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: const Color(0xFFF08A24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .3)),
                    const SizedBox(height: 2),
                    Text(_formatAuctionDate(value),
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_outlined, size: 17),
            ]),
          ),
        ),
      );

  void _setTimedBuyingDuration(Duration duration) {
    setState(() {
      final start = _auctionStartAt ?? DateTime.now().add(const Duration(minutes: 10));
      _auctionStartAt = start;
      _auctionEndAt = start.add(duration);
    });
  }

`;

const auctionPattern = /  Widget _auctionSetupCard\(\) => Card\([\s\S]*?\n\n  Future<void> _pickAuctionDate/;
if (!source.includes('QUICK DURATION')) {
  if (!auctionPattern.test(source)) {
    throw new Error('Could not isolate _auctionSetupCard for professional Timed Buying terms.');
  }
  source = source.replace(
    auctionPattern,
    `${timedTermsReplacement}  Future<void> _pickAuctionDate`,
  );
}

// Ensure all detailed industrial categories persist the structured fields that
// the form now collects. Heavy Equipment still uses the controlled brand/model
// catalog; other categories keep their free-text brand/model values.
const publishFlagAnchor = "      final isMachine = _category == 'Heavy Equipment';\n      final isProperty = _isProperty;";
if (!source.includes("final isDetailedAsset = const {\n        'Heavy Equipment'")) {
  if (!source.includes(publishFlagAnchor)) {
    throw new Error('Could not locate publish detailed-asset flag anchor.');
  }
  source = source.replace(
    publishFlagAnchor,
    "      final isMachine = _category == 'Heavy Equipment';\n      final isDetailedAsset = const {\n        'Heavy Equipment',\n        'Transport & Hauling',\n        'Oil & Gas Equipment',\n        'Oilfield & Drilling',\n        'Site Support',\n      }.contains(_category);\n      final isProperty = _isProperty;",
  );
}

optionalReplace("'modelYear': isMachine ? _equipmentYear : null,", "'modelYear': isDetailedAsset ? _equipmentYear : null,");
optionalReplace("'machineHours': isMachine\n            ? int.tryParse", "'machineHours': isDetailedAsset\n            ? int.tryParse");
optionalReplace("'operatingStatus': isMachine ? _operatingStatus : null,", "'operatingStatus': isDetailedAsset ? _operatingStatus : null,");
optionalReplace("'maintenanceHistory': isMachine ? _maintenanceHistory : null,", "'maintenanceHistory': isDetailedAsset ? _maintenanceHistory : null,");
optionalReplace("'serialNumber': isMachine ? _serialNumber.text.trim() : null,", "'serialNumber': isDetailedAsset ? _serialNumber.text.trim() : null,");
optionalReplace("'engineDetails': isMachine ? _engineDetails.text.trim() : null,", "'engineDetails': isDetailedAsset ? _engineDetails.text.trim() : null,");
optionalReplace("'attachments': isMachine ? _attachments.text.trim() : null,", "'attachments': isDetailedAsset ? _attachments.text.trim() : null,");

if (!source.includes('MarketplaceListingPlacementSelector(') ||
    !source.includes("title: 'Review & publish'") ||
    !source.includes("title: 'Timed Buying terms'") ||
    !source.includes('isDetailedAsset')) {
  throw new Error('Professional listing form migration did not produce all required markers.');
}

fs.writeFileSync(target, source, 'utf8');
console.log(`updated ${relative}`);
console.log('Professional listing form + Timed Buying terms migration applied.');
console.log('Internal Auction transaction values remain unchanged for Firebase compatibility.');
