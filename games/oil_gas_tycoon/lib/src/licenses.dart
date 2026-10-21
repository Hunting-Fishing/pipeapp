import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'assets.dart';

bool _registered = false;

/// Makes bundled font, art, and audio attributions available in both entrypoints.
void registerTycoonLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final assets = await TycoonAssets.load();
    yield LicenseEntryWithLineBreaks(
      const ['Roboto font family'],
      await rootBundle.loadString(assets.resolve('assets/fonts/LICENSE.txt')),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Kenney industrial art, vehicles, and interface sounds'],
      await rootBundle.loadString(assets.resolve('assets/licenses/kenney.txt')),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Oil & Gas Tycoon original oilfield art'],
      await rootBundle
          .loadString(assets.resolve('assets/licenses/original-art.txt')),
    );
  });
}
