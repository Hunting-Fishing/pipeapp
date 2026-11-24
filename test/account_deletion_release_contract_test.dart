import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('immediate deletion is queued fail closed and processed frequently', () {
    final commands = source('firebase/functions/account_privacy_commands.js');
    final index = source('firebase/functions/index.js');
    final storageRules = source('firebase/storage.rules');

    expect(commands, contains('checkAccountDeletionReadiness'));
    expect(commands, contains('mode === "immediate"'));
    expect(commands, contains('pending_apple_revocation'));
    expect(commands, contains('appleDeletionAuthorizationId'));
    expect(commands, contains('claimAccountDeletion'));
    expect(commands, contains('account_deletion_tombstones'));
    expect(commands, contains('DELETION_MUTATION_DRAIN_MINUTES = 2'));
    expect(commands, contains('quiescencePending'));
    expect(commands, contains('recoverBlockedAccountDeletion'));
    expect(commands, contains('{disabled: false}'));
    expect(commands, contains('updateUser(identity.uid, {disabled: true})'));
    expect(commands, contains('revokeRefreshTokens(identity.uid)'));
    expect(
      commands,
      contains('Immediate account deletion cannot be cancelled.'),
    );
    expect(index, contains('exports.checkAccountDeletionReadiness = onCall('));
    expect(index, contains('"every 15 minutes"'));
    expect(storageRules, contains('account_deletion_tombstones'));
    expect(commands, contains(r'business_logos/${uid}/'));
    expect(commands, contains('deleteOwnedAccountMedia(document.id)'));
    expect(commands, contains('sellerUid: FieldValue.delete()'));
    for (final entrypoint in <String>[
      'firebase/functions/index.js',
      'firebase/functions/bootstrap.js',
      'firebase/functions/production_bootstrap.js',
    ]) {
      expect(source(entrypoint), contains('guardCallableHandler'));
    }
  });

  test('Apple revocation completes before the deletion command is queued', () {
    final apple = source('lib/auth/firebase_auth/apple_auth.dart');
    final account = source('lib/marketplace/marketplace_account_hub.dart');

    expect(apple, contains('reauthenticateWithCredential'));
    expect(apple, contains('AppleAuthProvider.credentialWithIDToken'));
    expect(apple, contains('revokeTokenWithAuthorizationCode'));
    expect(apple, contains('requiredByServer'));
    final reauthentication = apple.indexOf('reauthenticateWithCredential');
    final tokenRefresh = apple.indexOf('getIdToken(true)', reauthentication);
    final destructiveRevocation =
        apple.indexOf('revokeTokenWithAuthorizationCode', tokenRefresh);
    expect(reauthentication, greaterThanOrEqualTo(0));
    expect(tokenRefresh, greaterThan(reauthentication));
    expect(destructiveRevocation, greaterThan(tokenRefresh));
    final readiness = account.indexOf("'checkAccountDeletionReadiness'");
    final revocation =
        account.indexOf('revokeAppleAuthorizationForAccountDeletion(');
    final request = account.indexOf("'requestAccountDeletion'", readiness);
    expect(readiness, greaterThanOrEqualTo(0));
    expect(revocation, greaterThan(readiness));
    expect(request, greaterThan(revocation));
    expect(
      account.substring(revocation, request),
      contains('requiredByServer: true'),
    );
    expect(
      account.substring(revocation, request),
      contains('appleRevocationCompleted = true'),
    );
    expect(
      account.substring(readiness, request),
      contains('appleDeletionAuthorizationId'),
    );
    expect(account, contains('Account access has been disabled.'));
    expect(account, isNot(contains('You have been signed out.')));
  });

  test('public web route accepts a deletion request without reinstalling', () {
    final configuration = source('lib/core/config/public_release_config.dart');
    final publicPage =
        source('lib/marketplace/marketplace_public_information.dart');

    expect(configuration, contains('accountDeletionMailto'));
    expect(configuration, contains('Pipe Buyer account deletion request'));
    expect(publicPage, contains('Request deletion without the app'));
    expect(publicPage, contains('You do not need to reinstall or open'));
    expect(publicPage, contains('Request account deletion:'));

    final supportStart = publicPage.indexOf('class _PublicSupport');
    final deletionStart = publicPage.indexOf('class _AccountDeletion');
    final supportSection = publicPage.substring(supportStart, deletionStart);
    final deletionSection = publicPage.substring(deletionStart);
    expect(supportSection, contains('configuration.supportMailto'));
    expect(
        supportSection, isNot(contains('configuration.accountDeletionMailto')));
    expect(deletionSection, contains('configuration.accountDeletionMailto'));
  });
}
