import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const relative = 'lib/marketplace/oil_gas_marketplace.dart';
const target = path.join(process.cwd(), relative);
if (!fs.existsSync(target)) throw new Error(`Missing ${relative}`);

let source = fs.readFileSync(target, 'utf8');
if (!source.includes('MarketplaceListingResponsiveFields(') ||
    !source.includes('isDetailedAsset')) {
  throw new Error('Professional listing form base migration must run first.');
}

const replacement = `            if (isDetailedAsset) ...[
              MarketplaceListingResponsiveFields(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _equipmentYear,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isMachine ? 'Model year *' : 'Year (optional)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    items: List.generate(
                      DateTime.now().year - 1949,
                      (index) => DateTime.now().year - index,
                    )
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _equipmentYear = value),
                    validator: (_) => isMachine && _equipmentYear == null
                        ? 'Select the model year'
                        : null,
                  ),
                  TextFormField(
                    controller: _machineHours,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isMachine
                          ? 'Machine hours'
                          : 'Runtime / hours (optional)',
                      suffixText: 'hours',
                      prefixIcon: const Icon(Icons.schedule),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MarketplaceListingResponsiveFields(
                children: [
                  TextFormField(
                    controller: _serialNumber,
                    decoration: const InputDecoration(
                      labelText: 'Serial / VIN / PIN (optional)',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: _engineDetails,
                    decoration: const InputDecoration(
                      labelText: 'Engine / power / drive details',
                      hintText: 'Engine model, horsepower, transmission',
                      prefixIcon: Icon(Icons.settings_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _attachments,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Attachments / included equipment',
                  hintText: 'Buckets, forks, service body, compressor, tools, etc.',
                  prefixIcon: Icon(Icons.construction_outlined),
                ),
              ),
              const SizedBox(height: 10),
              MarketplaceListingResponsiveFields(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _operatingStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Operating status',
                      prefixIcon: Icon(Icons.engineering_outlined),
                    ),
                    selectedItemBuilder: (context) => const [
                      'Operational',
                      'Operational with known issues',
                      'Not currently operational',
                      'For parts / rebuild',
                    ]
                        .map((value) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(value),
                            ))
                        .toList(),
                    items: const [
                      'Operational',
                      'Operational with known issues',
                      'Not currently operational',
                      'For parts / rebuild',
                    ].map((value) {
                      final visual = _operatingStatusVisual(value);
                      return DropdownMenuItem(
                        value: value,
                        child: MarketplaceFormOption(
                          label: value,
                          icon: visual.icon,
                          iconColor: visual.color,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(
                      () => _operatingStatus = value ?? 'Operational',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _maintenanceHistory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Maintenance history',
                      prefixIcon: Icon(Icons.history_outlined),
                    ),
                    selectedItemBuilder: (context) => const [
                      'Full documented history',
                      'Partial maintenance records',
                      'Owner-maintained — no records',
                      'Unknown / not available',
                    ]
                        .map((value) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(value),
                            ))
                        .toList(),
                    items: const [
                      'Full documented history',
                      'Partial maintenance records',
                      'Owner-maintained — no records',
                      'Unknown / not available',
                    ].map((value) {
                      final visual = _maintenanceVisual(value);
                      return DropdownMenuItem(
                        value: value,
                        child: MarketplaceFormOption(
                          label: value,
                          icon: visual.icon,
                          iconColor: visual.color,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(
                      () => _maintenanceHistory =
                          value ?? 'Unknown / not available',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (!isProperty) ...[`;

const pattern = /            if \(isDetailedAsset\) \.\.\.\[[\s\S]*?            \],\n            if \(!isProperty\) \.\.\.\[/;
if (!source.includes("hintText: 'Buckets, forks, service body, compressor, tools, etc.'")) {
  if (!pattern.test(source)) {
    throw new Error('Could not isolate the structured industrial detail block.');
  }
  source = source.replace(pattern, replacement);
}

if (!source.includes("labelText: 'Serial / VIN / PIN (optional)'") ||
    !source.includes('MarketplaceListingResponsiveFields(')) {
  throw new Error('Compact professional industrial fields were not produced.');
}

fs.writeFileSync(target, source, 'utf8');
console.log(`updated ${relative}`);
console.log('Responsive industrial specification fields applied.');
