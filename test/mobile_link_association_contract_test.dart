import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares both production Universal Link domains', () {
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(
      entitlements,
      contains('<key>com.apple.developer.associated-domains</key>'),
    );
    expect(entitlements, contains('<string>applinks:pipebuyer.com</string>'));
    expect(
      entitlements,
      contains('<string>applinks:www.pipebuyer.com</string>'),
    );
  });

  test('Android keeps legacy links and declares both production App Link hosts',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final filters = RegExp(
      r'<intent-filter(?<attributes>[^>]*)>(?<body>.*?)</intent-filter>',
      dotAll: true,
    ).allMatches(manifest).map((match) {
      return (
        attributes: match.namedGroup('attributes')!,
        body: match.namedGroup('body')!,
      );
    }).toList();
    final customScheme = filters.singleWhere(
      (filter) => filter.body.contains('android:scheme="pipeapp"'),
    );
    expect(customScheme.attributes, isNot(contains('autoVerify')));
    expect(customScheme.body, contains('android:host="pipeapp.com"'));

    final verifiedFilters = filters
        .where((filter) => filter.attributes.contains('autoVerify="true"'))
        .toList();
    expect(verifiedFilters, hasLength(2));
    const expectedPathRules = <String>{
      'path:/',
      'path:/about',
      'path:/privacy',
      'path:/terms',
      'path:/support',
      'path:/account-deletion',
      'path:/services',
      'path:/contact-center',
      'path:/partner',
      'path:/insurance',
      'path:/shop',
      'path:/auth/action',
      'pathPrefix:/listings/',
      'pathPrefix:/auctions/',
      'pathPrefix:/profiles/',
      'pathPrefix:/conversations/',
      'pathPrefix:/dispatch/jobs/',
      'pathPrefix:/services/',
      'pathPrefix:/partner/',
      'pathPrefix:/insurance/',
      'pathPrefix:/shop/',
    };
    for (final filter in verifiedFilters) {
      expect(filter.body, contains('android:scheme="https"'));
      expect(filter.body, contains('android.intent.category.DEFAULT'));
      expect(filter.body, contains('android.intent.category.BROWSABLE'));
      final pathRules = RegExp(
        r'android:(path|pathPrefix)="([^"]+)"',
      ).allMatches(filter.body).map((match) {
        return '${match.group(1)}:${match.group(2)}';
      }).toSet();
      expect(pathRules, unorderedEquals(expectedPathRules));
      expect(filter.body, isNot(contains('android:pathPrefix="/"')));
      expect(filter.body, isNot(contains('/__/')));
      expect(filter.body, isNot(contains('android:path="/admin')));
      expect(filter.body, isNot(contains('android:pathPrefix="/admin')));
    }
    expect(
      verifiedFilters.map((filter) {
        return RegExp(r'android:host="([^"]+)"')
            .firstMatch(filter.body)!
            .group(1);
      }).toSet(),
      {'pipebuyer.com', 'www.pipebuyer.com'},
    );
  });

  test('Firebase can serve generated well-known association documents', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync())
        as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final ignored = (hosting['ignore'] as List<dynamic>).cast<String>();
    expect(ignored, isNot(contains('**/.*')));
    expect(ignored, contains('**/.git/**'));
    expect(ignored, contains('**/.last_build_id'));
    expect(hosting['appAssociation'], equals('NONE'));
    final headers =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final source in const {
      '/.well-known/apple-app-site-association',
      '/.well-known/assetlinks.json',
    }) {
      final entry = headers.singleWhere((entry) => entry['source'] == source);
      final values = {
        for (final header
            in (entry['headers'] as List<dynamic>).cast<Map<String, dynamic>>())
          header['key']: header['value'],
      };
      expect(values['Content-Type'], 'application/json');
      expect(values['Cache-Control'], contains('no-store'));
    }
  });

  test('association generator fails closed without a Play signing fingerprint',
      () {
    final tool = File('tool/mobile_link_associations.mjs').readAsStringSync();
    expect(tool, contains('Play App Signing SHA-256'));
    expect(tool, contains('Invalid Play App Signing SHA-256'));
    expect(tool, contains('output must be an explicit .well-known directory'));
    expect(tool, isNot(contains('REPLACE_WITH_PLAY_CERT')));
  });
}
