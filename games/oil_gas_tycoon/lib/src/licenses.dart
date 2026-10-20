import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Makes the bundled font attribution available in both app entrypoints.
void registerTycoonLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    const localKey = 'assets/fonts/LICENSE.txt';
    const packageKey = 'packages/oil_gas_tycoon/$localKey';
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final key =
        manifest.listAssets().contains(packageKey) ? packageKey : localKey;
    yield LicenseEntryWithLineBreaks(
      const ['Roboto font family'],
      await rootBundle.loadString(key),
    );
  });
}
