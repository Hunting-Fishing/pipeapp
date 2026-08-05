from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected one match in {relative_path}, found {count}: {old[:120]!r}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_once(relative_path: str, marker: str, addition: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    if marker in text:
        return
    path.write_text(text.rstrip() + "\n\n" + addition.strip() + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# New profile-specific helpers.
# ---------------------------------------------------------------------------
(ROOT / "lib/marketplace/marketplace_profile_feedback.dart").write_text(
    """import 'package:firebase_core/firebase_core.dart';

String incompleteProfileMessage(Iterable<String> fields) {
  final missing = fields
      .map((field) => field.trim())
      .where((field) => field.isNotEmpty)
      .toList(growable: false);
  if (missing.length == 1 && missing.single == 'Primary community') {
    return 'Please select your primary community on the map before continuing.';
  }
  if (missing.length == 1) {
    return 'Please complete ${missing.single} before continuing.';
  }
  if (missing.isEmpty) {
    return 'Please complete the highlighted profile fields before continuing.';
  }
  final visible = missing.take(3).join(', ');
  final suffix = missing.length > 3 ? ', and ${missing.length - 3} more' : '';
  return 'Please complete the highlighted profile fields before continuing: '
      '$visible$suffix.';
}

String profileOperationErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is FirebaseException) {
    switch (error.code.toLowerCase()) {
      case 'unauthenticated':
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Your sign-in session expired. Sign in again, then retry.';
      case 'permission-denied':
      case 'unauthorized':
        return 'Your profile changes were not accepted. Refresh your sign-in '
            'and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'network-error':
        return 'Pipe Buyer could not reach profile storage. Check your '
            'connection and try again.';
      case 'aborted':
      case 'already-exists':
        return 'Another profile update was detected. Reload the profile and '
            'try again.';
      case 'invalid-argument':
      case 'failed-precondition':
        return 'Some profile information is incomplete or invalid. Review the '
            'highlighted fields and try again.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return 'Profile storage is temporarily busy. Please try again later.';
    }
  }

  final description = error.toString().toLowerCase();
  if (description.contains('sign in') ||
      description.contains('not signed in') ||
      description.contains('session')) {
    return 'Your sign-in session expired. Sign in again, then retry.';
  }
  return fallback;
}
""",
    encoding="utf-8",
)

(ROOT / "lib/marketplace/marketplace_profile_community.dart").write_text(
    """import 'marketplace_location.dart';

String primaryCommunityLabel(MarketplaceLocation location) {
  final publicName = location.publicName.trim();
  if (publicName.isNotEmpty) return publicName;
  final townRegion = [location.nearestTown.trim(), location.region.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');
  return townRegion.isEmpty ? 'Primary community' : townRegion;
}

MarketplaceLocation normalizePrimaryCommunityLocation(
  MarketplaceLocation location,
) =>
    MarketplaceLocation(
      point: location.point,
      visibility: LocationVisibility.approximate,
      publicName: primaryCommunityLabel(location),
      address: location.address,
      nearestTown: location.nearestTown,
      accessNotes: location.accessNotes,
      region: location.region,
      postalCode: location.postalCode,
      country: location.country,
    );

Map<String, dynamic> primaryCommunityPrivateData(
  MarketplaceLocation location,
  String ownerUid,
) =>
    normalizePrimaryCommunityLocation(location).privateData(ownerUid);

Map<String, dynamic> primaryCommunityPublicData(
  MarketplaceLocation location,
) =>
    normalizePrimaryCommunityLocation(location).publicData();
""",
    encoding="utf-8",
)

# ---------------------------------------------------------------------------
# Profile page: structured community selection, complete validation, and
# profile-specific feedback.
# ---------------------------------------------------------------------------
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "import 'marketplace_profile_repository.dart';\nimport 'marketplace_profile_tags.dart';",
    "import 'marketplace_profile_repository.dart';\n"
    "import 'marketplace_profile_community.dart';\n"
    "import 'marketplace_profile_feedback.dart';\n"
    "import 'marketplace_profile_tags.dart';",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "  MarketplaceServiceArea? _serviceAreaSelection;\n"
    "  MarketplaceLocation? _businessYardLocation;",
    "  MarketplaceServiceArea? _serviceAreaSelection;\n"
    "  MarketplaceLocation? _primaryCommunityLocation;\n"
    "  MarketplaceLocation? _businessYardLocation;",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "      _phone.text = '${personal['phone_number'] ?? ''}';\n"
    "      _community.text =\n"
    "          '${personal['baseCommunity'] ?? publicSeller?['baseCommunity'] ?? ''}';",
    "      _phone.text = '${personal['pendingPhoneE164'] ?? "
    "personal['verifiedPhoneE164'] ?? personal['phone_number'] ?? "
    "user.phoneNumber ?? ''}';\n"
    "      _community.text =\n"
    "          '${personal['baseCommunity'] ?? publicSeller?['baseCommunity'] ?? ''}';\n"
    "      final primaryCommunity = personal['primaryCommunityLocation'];\n"
    "      if (primaryCommunity is Map) {\n"
    "        try {\n"
    "          _primaryCommunityLocation = normalizePrimaryCommunityLocation(\n"
    "            MarketplaceLocation.fromPrivateData(\n"
    "              Map<String, dynamic>.from(primaryCommunity),\n"
    "            ),\n"
    "          );\n"
    "          _community.text =\n"
    "              primaryCommunityLabel(_primaryCommunityLocation!);\n"
    "        } catch (_) {\n"
    "          _loadIssues.add('Primary community map');\n"
    "        }\n"
    "      }",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "            _displayName.text,\n"
    "            _phone.text,\n"
    "            _community.text,\n"
    "            _personalBio.text,",
    "            _displayName.text,\n"
    "            _phone.text,\n"
    "            _primaryCommunityLocation == null ? '' : 'selected',\n"
    "            _personalBio.text,",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "      if (_community.text.trim().isEmpty) ('Community', _communityKey),",
    "      if (_primaryCommunityLocation == null)\n"
    "        ('Primary community', _communityKey),",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "            _field(_community, 'Base community',\n"
    "                hint: 'Grande Prairie, Alberta',\n"
    "                completionRequired: true,\n"
    "                fieldKey: _communityKey),",
    "            _primaryCommunityField(),",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "  Widget _businessForm() => Padding(",
    "  Widget _primaryCommunityField() {\n"
    "    final selected = _primaryCommunityLocation;\n"
    "    final legacyLabel = _community.text.trim();\n"
    "    final missing = selected == null;\n"
    "    final subtitle = selected != null\n"
    "        ? '${primaryCommunityLabel(selected)}\\nExact pin private • broad area used for nearby results'\n"
    "        : legacyLabel.isNotEmpty\n"
    "            ? '$legacyLabel • Confirm this community on the map'\n"
    "            : 'Select a city, town, municipality, or operating area';\n"
    "    return Container(\n"
    "      key: _communityKey,\n"
    "      margin: const EdgeInsets.only(bottom: 11),\n"
    "      decoration: _missingDecoration(missing),\n"
    "      child: ListTile(\n"
    "        leading: const Icon(Icons.map_outlined, color: Color(0xFF0878E8)),\n"
    "        title: const Text('Primary community',\n"
    "            style: TextStyle(fontWeight: FontWeight.w800)),\n"
    "        subtitle: Text(subtitle),\n"
    "        isThreeLine: selected != null,\n"
    "        trailing: const Icon(Icons.chevron_right),\n"
    "        onTap: _saving ? null : _selectPrimaryCommunity,\n"
    "      ),\n"
    "    );\n"
    "  }\n\n"
    "  Future<void> _selectPrimaryCommunity() async {\n"
    "    final selected = await MarketplaceLocationPicker.showCommunity(\n"
    "      context,\n"
    "      _primaryCommunityLocation,\n"
    "    );\n"
    "    if (selected == null || !mounted) return;\n"
    "    final normalized = normalizePrimaryCommunityLocation(selected);\n"
    "    setState(() {\n"
    "      _primaryCommunityLocation = normalized;\n"
    "      _community.text = primaryCommunityLabel(normalized);\n"
    "    });\n"
    "    _scheduleCompletionSync();\n"
    "  }\n\n"
    "  Widget _businessForm() => Padding(",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n"
    "          content: Text(\n"
    "              'Account changed to ${requested == 'business' ? 'Business' : 'Personal'}. Complete the active profile.')));\n"
    "    } catch (_) {\n"
    "      if (mounted) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(\n"
    "            content: Text('Could not change the account type.')));\n"
    "      }",
    "      PipeFeedback.show(\n"
    "        context,\n"
    "        message:\n"
    "            'Account changed to ${requested == 'business' ? 'Business' : 'Personal'}. Complete the active profile.',\n"
    "        tone: PipeStatusTone.success,\n"
    "      );\n"
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: profileOperationErrorMessage(\n"
    "            error,\n"
    "            fallback:\n"
    "                'The account type could not be changed right now. Please try again.',\n"
    "          ),\n"
    "          tone: PipeStatusTone.error,\n"
    "        );\n"
    "      }",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "    await _repo.saveLocation(\n"
    "        location: location.privateData(FirebaseAuth.instance.currentUser!.uid),\n"
    "        purpose: purpose);\n"
    "    await _reloadSavedLocations();",
    "    try {\n"
    "      await _repo.saveLocation(\n"
    "          location:\n"
    "              location.privateData(FirebaseAuth.instance.currentUser!.uid),\n"
    "          purpose: purpose);\n"
    "      await _reloadSavedLocations();\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(context,\n"
    "            message: 'Saved location added.',\n"
    "            tone: PipeStatusTone.success);\n"
    "      }\n"
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: profileOperationErrorMessage(error,\n"
    "              fallback:\n"
    "                  'This location could not be saved. Check your connection and try again.'),\n"
    "          tone: PipeStatusTone.error,\n"
    "        );\n"
    "      }\n"
    "    }",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "    await _repo.saveLocation(\n"
    "        id: '${data['id']}',\n"
    "        location: updated.privateData(FirebaseAuth.instance.currentUser!.uid),\n"
    "        purpose: '${data['purpose'] ?? 'saved_location'}');\n"
    "    await _reloadSavedLocations();",
    "    try {\n"
    "      await _repo.saveLocation(\n"
    "          id: '${data['id']}',\n"
    "          location:\n"
    "              updated.privateData(FirebaseAuth.instance.currentUser!.uid),\n"
    "          purpose: '${data['purpose'] ?? 'saved_location'}');\n"
    "      await _reloadSavedLocations();\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(context,\n"
    "            message: 'Saved location updated.',\n"
    "            tone: PipeStatusTone.success);\n"
    "      }\n"
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: profileOperationErrorMessage(error,\n"
    "              fallback:\n"
    "                  'This location could not be updated. Check your connection and try again.'),\n"
    "          tone: PipeStatusTone.error,\n"
    "        );\n"
    "      }\n"
    "    }",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "  Future<void> _removeSavedLocation(String id) async {\n"
    "    await _repo.deleteLocation(id);\n"
    "    await _reloadSavedLocations();\n"
    "  }",
    "  Future<void> _removeSavedLocation(String id) async {\n"
    "    try {\n"
    "      await _repo.deleteLocation(id);\n"
    "      await _reloadSavedLocations();\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(context,\n"
    "            message: 'Saved location removed.',\n"
    "            tone: PipeStatusTone.success);\n"
    "      }\n"
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: profileOperationErrorMessage(error,\n"
    "              fallback:\n"
    "                  'This location could not be removed. Please try again.'),\n"
    "          tone: PipeStatusTone.error,\n"
    "        );\n"
    "      }\n"
    "    }\n"
    "  }",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "  Future<void> _savePersonal() async {\n"
    "    if (!_personalKey.currentState!.validate()) return;\n"
    "    await _save(() => _repo.savePersonal({\n"
    "          'display_name': _displayName.text.trim(),\n"
    "          'phone_number': _phone.text.trim(),\n"
    "          'baseCommunity': _community.text.trim(),\n"
    "          'sellerBio': _personalBio.text.trim(),\n"
    "          'preferredContact': _preferredContact,\n"
    "          'personalProfileComplete': true,\n"
    "          'profileComplete': _accountType == 'personal',\n"
    "          'profileCompletion': _profileCompletion,\n"
    "        }));\n"
    "  }\n\n"
    "  Future<void> _saveBusiness() async {\n"
    "    if (!_businessKey.currentState!.validate()) return;\n"
    "    await _save(() => _repo.saveBusiness({",
    "  Future<bool> _validateProfile(GlobalKey<FormState> formKey) async {\n"
    "    final formValid = formKey.currentState?.validate() ?? false;\n"
    "    final missing = _missingProfileItems;\n"
    "    if (formValid && missing.isEmpty) return true;\n"
    "    if (mounted) setState(() {});\n"
    "    PipeFeedback.show(\n"
    "      context,\n"
    "      message: incompleteProfileMessage(missing.map((item) => item.$1)),\n"
    "      tone: PipeStatusTone.warning,\n"
    "    );\n"
    "    if (missing.isNotEmpty) await _goToMissing(missing.first.$2);\n"
    "    return false;\n"
    "  }\n\n"
    "  Future<void> _savePersonal() async {\n"
    "    if (!await _validateProfile(_personalKey)) return;\n"
    "    final primaryCommunity = _primaryCommunityLocation!;\n"
    "    await _save(() => _repo.savePersonal({\n"
    "          'display_name': _displayName.text.trim(),\n"
    "          'phone_number': _phone.text.trim(),\n"
    "          'baseCommunity': primaryCommunityLabel(primaryCommunity),\n"
    "          'sellerBio': _personalBio.text.trim(),\n"
    "          'preferredContact': _preferredContact,\n"
    "          'personalProfileComplete': true,\n"
    "          'profileComplete': _accountType == 'personal',\n"
    "          'profileCompletion': _profileCompletion,\n"
    "        }, primaryCommunity: primaryCommunity));\n"
    "  }\n\n"
    "  Future<void> _saveBusiness() async {\n"
    "    if (!await _validateProfile(_businessKey)) return;\n"
    "    await _save(() => _repo.saveBusiness({",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "      await action();\n"
    "      if (mounted) {\n"
    "        ScaffoldMessenger.of(context)\n"
    "            .showSnackBar(const SnackBar(content: Text('Profile saved.')));\n"
    "        if (widget.onboarding) {",
    "      await action();\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: 'Profile saved.',\n"
    "          tone: PipeStatusTone.success,\n"
    "        );\n"
    "        if (widget.onboarding) {",
)
replace_once(
    "lib/marketplace/marketplace_profile_page.dart",
    "    } catch (_) {\n"
    "      if (mounted) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(\n"
    "            content:\n"
    "                Text('Could not save. Check Firebase rules and sign-in.')));\n"
    "      }",
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: profileOperationErrorMessage(\n"
    "            error,\n"
    "            fallback:\n"
    "                'Your profile could not be saved right now. Please try again.',\n"
    "          ),\n"
    "          tone: PipeStatusTone.error,\n"
    "        );\n"
    "      }",
)

# ---------------------------------------------------------------------------
# Repository: transactionally create the required user baseline when Auth has
# completed before the private user document exists. Persist private exact and
# public approximate community representations atomically.
# ---------------------------------------------------------------------------
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "import 'regional_phone_field.dart';",
    "import 'marketplace_location.dart';\n"
    "import 'marketplace_profile_community.dart';\n"
    "import 'regional_phone_field.dart';",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "  Future<void> changeAccountType(String accountType) {\n"
    "    if (accountType != 'personal' && accountType != 'business') {\n"
    "      throw ArgumentError.value(accountType, 'accountType');\n"
    "    }\n"
    "    return _firestore.collection('users').doc(_uid).set({\n"
    "      'accountType': accountType,\n"
    "      'profileComplete': false,\n"
    "      'roleVersion': 0,\n"
    "      'accountTypeChangedAt': FieldValue.serverTimestamp(),\n"
    "      'roleSyncRequestedAt': FieldValue.serverTimestamp(),\n"
    "    }, SetOptions(merge: true));\n"
    "  }",
    "  Future<void> changeAccountType(String accountType) {\n"
    "    if (accountType != 'personal' && accountType != 'business') {\n"
    "      throw ArgumentError.value(accountType, 'accountType');\n"
    "    }\n"
    "    final uid = _uid;\n"
    "    final userRef = _firestore.collection('users').doc(uid);\n"
    "    return _firestore.runTransaction((transaction) async {\n"
    "      final snapshot = await transaction.get(userRef);\n"
    "      final values = <String, dynamic>{\n"
    "        'accountType': accountType,\n"
    "        'profileComplete': false,\n"
    "        'roleVersion': 0,\n"
    "        'accountTypeChangedAt': FieldValue.serverTimestamp(),\n"
    "        'roleSyncRequestedAt': FieldValue.serverTimestamp(),\n"
    "      };\n"
    "      if (!snapshot.exists) {\n"
    "        values.addAll({\n"
    "          'uid': uid,\n"
    "          'userScore': 70,\n"
    "          'accountVerified': false,\n"
    "        });\n"
    "      }\n"
    "      transaction.set(userRef, values, SetOptions(merge: true));\n"
    "    });\n"
    "  }",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "  Future<void> savePersonal(Map<String, dynamic> values) async {\n"
    "    final phone = normalizePhoneNumber('${values['phone_number'] ?? ''}');\n"
    "    final verifiedPhone = normalizePhoneNumber(\n"
    "        FirebaseAuth.instance.currentUser?.phoneNumber ?? '');\n"
    "    values = {...values}\n"
    "      ..remove('phone_number')\n"
    "      ..remove('phoneE164');\n"
    "    if (phone.isNotEmpty && phone != verifiedPhone) {\n"
    "      values['pendingPhoneE164'] = phone;\n"
    "    } else if (phone == verifiedPhone && phone.isNotEmpty) {\n"
    "      values['pendingPhoneE164'] = FieldValue.delete();\n"
    "    }\n"
    "    final batch = _firestore.batch();\n"
    "    batch.set(\n"
    "        _firestore.collection('users').doc(_uid),\n"
    "        {\n"
    "          ...values,\n"
    "          'uid': _uid,\n"
    "          'profileUpdatedAt': FieldValue.serverTimestamp(),\n"
    "        },\n"
    "        SetOptions(merge: true));\n"
    "    batch.set(\n"
    "        _firestore.collection('public_seller_profiles').doc(_uid),\n"
    "        {\n"
    "          'ownerUid': _uid,\n"
    "          'displayName': values['display_name'],\n"
    "          'description': values['sellerBio'],\n"
    "          'baseCommunity': values['baseCommunity'],\n"
    "          'updatedAt': FieldValue.serverTimestamp(),\n"
    "        },\n"
    "        SetOptions(merge: true));\n"
    "    await batch.commit();\n"
    "  }",
    "  Future<void> savePersonal(\n"
    "    Map<String, dynamic> values, {\n"
    "    required MarketplaceLocation primaryCommunity,\n"
    "  }) async {\n"
    "    final uid = _uid;\n"
    "    final phone = normalizePhoneNumber('${values['phone_number'] ?? ''}');\n"
    "    final verifiedPhone = normalizePhoneNumber(\n"
    "        FirebaseAuth.instance.currentUser?.phoneNumber ?? '');\n"
    "    final normalizedCommunity =\n"
    "        normalizePrimaryCommunityLocation(primaryCommunity);\n"
    "    final publicCommunity =\n"
    "        primaryCommunityPublicData(normalizedCommunity);\n"
    "    values = {...values}\n"
    "      ..remove('phone_number')\n"
    "      ..remove('phoneE164');\n"
    "    final userRef = _firestore.collection('users').doc(uid);\n"
    "    final publicRef =\n"
    "        _firestore.collection('public_seller_profiles').doc(uid);\n"
    "    await _firestore.runTransaction((transaction) async {\n"
    "      final userSnapshot = await transaction.get(userRef);\n"
    "      final userValues = <String, dynamic>{\n"
    "        ...values,\n"
    "        'uid': uid,\n"
    "        'baseCommunity': primaryCommunityLabel(normalizedCommunity),\n"
    "        'primaryCommunityLocation':\n"
    "            primaryCommunityPrivateData(normalizedCommunity, uid),\n"
    "        'profileUpdatedAt': FieldValue.serverTimestamp(),\n"
    "      };\n"
    "      if (!userSnapshot.exists) {\n"
    "        userValues.addAll({\n"
    "          'accountType': 'personal',\n"
    "          'userScore': 70,\n"
    "          'accountVerified': false,\n"
    "        });\n"
    "      }\n"
    "      if (phone.isNotEmpty && phone != verifiedPhone) {\n"
    "        userValues['pendingPhoneE164'] = phone;\n"
    "      } else if (userSnapshot.exists) {\n"
    "        userValues['pendingPhoneE164'] = FieldValue.delete();\n"
    "      }\n"
    "      transaction.set(userRef, userValues, SetOptions(merge: true));\n"
    "      transaction.set(\n"
    "          publicRef,\n"
    "          {\n"
    "            'ownerUid': uid,\n"
    "            'displayName': values['display_name'],\n"
    "            'description': values['sellerBio'],\n"
    "            'baseCommunity': primaryCommunityLabel(normalizedCommunity),\n"
    "            'primaryCommunity': publicCommunity,\n"
    "            'primaryCommunityGeoPoint':\n"
    "                publicCommunity['publicGeoPoint'],\n"
    "            'primaryCommunityTown': publicCommunity['nearestTown'],\n"
    "            'primaryCommunityRegion': publicCommunity['region'],\n"
    "            'primaryCommunityCountry': publicCommunity['country'],\n"
    "            'updatedAt': FieldValue.serverTimestamp(),\n"
    "          },\n"
    "          SetOptions(merge: true));\n"
    "    });\n"
    "  }",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "  Future<void> saveBusiness(Map<String, dynamic> values) async {\n"
    "    final batch = _firestore.batch();\n"
    "    batch.set(\n"
    "        _firestore.collection('public_business_profiles').doc(_uid),",
    "  Future<void> saveBusiness(Map<String, dynamic> values) async {\n"
    "    final uid = _uid;\n"
    "    final publicRef =\n"
    "        _firestore.collection('public_business_profiles').doc(uid);\n"
    "    final privateRef = _firestore.collection('business_private').doc(uid);\n"
    "    final userRef = _firestore.collection('users').doc(uid);\n"
    "    await _firestore.runTransaction((transaction) async {\n"
    "      final userSnapshot = await transaction.get(userRef);\n"
    "      transaction.set(\n"
    "        publicRef,",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "        SetOptions(merge: true));\n"
    "    batch.set(\n"
    "        _firestore.collection('business_private').doc(_uid),",
    "        SetOptions(merge: true),\n"
    "      );\n"
    "      transaction.set(\n"
    "        privateRef,",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "          'ownerUid': _uid,\n"
    "          'memberUids': FieldValue.arrayUnion([_uid]),",
    "          'ownerUid': uid,\n"
    "          'memberUids': FieldValue.arrayUnion([uid]),",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "        SetOptions(merge: true));\n"
    "    batch.set(\n"
    "        _firestore.collection('users').doc(_uid),\n"
    "        {\n"
    "          'businessProfileComplete': true,\n"
    "          'profileComplete': true,\n"
    "          'profileCompletion': values['profileCompletion'],\n"
    "          'profileUpdatedAt': FieldValue.serverTimestamp(),\n"
    "        },\n"
    "        SetOptions(merge: true));\n"
    "    await batch.commit();\n"
    "  }",
    "        SetOptions(merge: true),\n"
    "      );\n"
    "      final userValues = <String, dynamic>{\n"
    "        'businessProfileComplete': true,\n"
    "        'profileComplete': true,\n"
    "        'profileCompletion': values['profileCompletion'],\n"
    "        'profileUpdatedAt': FieldValue.serverTimestamp(),\n"
    "      };\n"
    "      if (!userSnapshot.exists) {\n"
    "        userValues.addAll({\n"
    "          'uid': uid,\n"
    "          'accountType': 'business',\n"
    "          'userScore': 70,\n"
    "          'accountVerified': false,\n"
    "        });\n"
    "      }\n"
    "      transaction.set(userRef, userValues, SetOptions(merge: true));\n"
    "    });\n"
    "  }",
)
replace_once(
    "lib/marketplace/marketplace_profile_repository.dart",
    "          'ownerUid': _uid,\n          'updatedAt': FieldValue.serverTimestamp(),",
    "          'ownerUid': uid,\n          'updatedAt': FieldValue.serverTimestamp(),",
)

# ---------------------------------------------------------------------------
# Map picker: dedicated community mode with private exact pin and forced broad
# public location. Replace raw platform errors with user-safe feedback.
# ---------------------------------------------------------------------------
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "import 'package:latlong2/latlong.dart';\n\nimport 'marketplace_location.dart';",
    "import 'package:latlong2/latlong.dart';\n\n"
    "import '../core/accessibility/pipe_status_feedback.dart';\n"
    "import 'marketplace_location.dart';",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "  const MarketplaceLocationPicker(\n"
    "      {super.key,\n"
    "      this.initial,\n"
    "      this.title = 'Listing location',\n"
    "      this.delivery = false});\n\n"
    "  final MarketplaceLocation? initial;\n"
    "  final String title;\n"
    "  final bool delivery;",
    "  const MarketplaceLocationPicker(\n"
    "      {super.key,\n"
    "      this.initial,\n"
    "      this.title = 'Listing location',\n"
    "      this.delivery = false,\n"
    "      this.community = false})\n"
    "      : assert(!(delivery && community));\n\n"
    "  final MarketplaceLocation? initial;\n"
    "  final String title;\n"
    "  final bool delivery;\n"
    "  final bool community;",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "  static Future<MarketplaceLocation?> showDelivery(\n"
    "          BuildContext context, MarketplaceLocation? initial) =>\n"
    "      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(\n"
    "          fullscreenDialog: true,\n"
    "          builder: (_) => MarketplaceLocationPicker(\n"
    "              initial: initial,\n"
    "              title: 'Delivery destination',\n"
    "              delivery: true)));",
    "  static Future<MarketplaceLocation?> showDelivery(\n"
    "          BuildContext context, MarketplaceLocation? initial) =>\n"
    "      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(\n"
    "          fullscreenDialog: true,\n"
    "          builder: (_) => MarketplaceLocationPicker(\n"
    "              initial: initial,\n"
    "              title: 'Delivery destination',\n"
    "              delivery: true)));\n\n"
    "  static Future<MarketplaceLocation?> showCommunity(\n"
    "          BuildContext context, MarketplaceLocation? initial) =>\n"
    "      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(\n"
    "          fullscreenDialog: true,\n"
    "          builder: (_) => MarketplaceLocationPicker(\n"
    "              initial: initial,\n"
    "              title: 'Primary community',\n"
    "              community: true)));",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "    _visibility = widget.delivery\n"
    "        ? LocationVisibility.exact\n"
    "        : initial?.visibility ?? LocationVisibility.approximate;",
    "    _visibility = widget.delivery\n"
    "        ? LocationVisibility.exact\n"
    "        : widget.community\n"
    "            ? LocationVisibility.approximate\n"
    "            : initial?.visibility ?? LocationVisibility.approximate;",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "        text: initial?.publicName ??\n"
    "            (widget.delivery ? '' : 'Grande Prairie area, AB'));",
    "        text: initial?.publicName ??\n"
    "            (widget.delivery || widget.community\n"
    "                ? ''\n"
    "                : 'Grande Prairie area, AB'));",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "          Text(\n"
    "              widget.delivery\n"
    "                  ? 'Drop the pin at the delivery destination'\n"
    "                  : 'Drop the pin at the real pickup location',",
    "          Text(\n"
    "              widget.community\n"
    "                  ? 'Choose your primary community or operating area'\n"
    "                  : widget.delivery\n"
    "                      ? 'Drop the pin at the delivery destination'\n"
    "                      : 'Drop the pin at the real pickup location',",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "          Text(widget.delivery\n"
    "              ? 'The exact destination is stored privately with your offer and trucking request.'\n"
    "              : 'The exact pin is stored privately unless you choose to publish it.'),",
    "          Text(widget.community\n"
    "              ? 'The exact pin is stored privately. Only a broad area is used for local search and nearby results.'\n"
    "              : widget.delivery\n"
    "                  ? 'The exact destination is stored privately with your offer and trucking request.'\n"
    "                  : 'The exact pin is stored privately unless you choose to publish it.'),",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "              label: widget.delivery\n"
    "                  ? 'Search destination, landmark or nearest town'\n"
    "                  : 'Find an address or place',\n"
    "              hint: widget.delivery\n"
    "                  ? 'Try Tomslake, Dawson Creek, a yard, farm, landmark or postal code'\n"
    "                  : 'Start typing a street, town, lease or postal code',",
    "              label: widget.community\n"
    "                  ? 'Search city, town, municipality or operating area'\n"
    "                  : widget.delivery\n"
    "                      ? 'Search destination, landmark or nearest town'\n"
    "                      : 'Find an address or place',\n"
    "              hint: widget.community\n"
    "                  ? 'Try Grande Prairie, Alberta or a nearby municipality'\n"
    "                  : widget.delivery\n"
    "                      ? 'Try Tomslake, Dawson Creek, a yard, farm, landmark or postal code'\n"
    "                      : 'Start typing a street, town, lease or postal code',",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "                  labelText: widget.delivery\n"
    "                      ? 'Delivery address, yard, farm or site name'\n"
    "                      : 'Street, rural route, LSD or site name',\n"
    "                  hintText: widget.delivery\n"
    "                      ? 'e.g. Tomslake property, CJSM Yard or Lease 12-34'\n"
    "                      : 'e.g. 25 km west on Highway 43',\n"
    "                  helperText: widget.delivery\n"
    "                      ? 'Describe the actual site—not only the nearest town.'\n"
    "                      : null,",
    "                  labelText: widget.community\n"
    "                      ? 'Selected place or address (private)'\n"
    "                      : widget.delivery\n"
    "                          ? 'Delivery address, yard, farm or site name'\n"
    "                          : 'Street, rural route, LSD or site name',\n"
    "                  hintText: widget.community\n"
    "                      ? 'Optional street, rural area, or landmark'\n"
    "                      : widget.delivery\n"
    "                          ? 'e.g. Tomslake property, CJSM Yard or Lease 12-34'\n"
    "                          : 'e.g. 25 km west on Highway 43',\n"
    "                  helperText: widget.community\n"
    "                      ? 'This detail and the exact pin stay private.'\n"
    "                      : widget.delivery\n"
    "                          ? 'Describe the actual site—not only the nearest town.'\n"
    "                          : null,",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "                  labelText: widget.delivery\n"
    "                      ? 'Nearest recognized town *'\n"
    "                      : 'Nearest recognized town',\n"
    "                  hintText: widget.delivery\n"
    "                      ? 'e.g. Dawson Creek, British Columbia'\n"
    "                      : 'e.g. Grande Prairie, Alberta',\n"
    "                  helperText: widget.delivery\n"
    "                      ? 'For a rural Tomslake destination, Dawson Creek may be the nearest well-known service town.'\n"
    "                      : null)),",
    "                  labelText: widget.community\n"
    "                      ? 'City, town or municipality *'\n"
    "                      : widget.delivery\n"
    "                          ? 'Nearest recognized town *'\n"
    "                          : 'Nearest recognized town',\n"
    "                  hintText: widget.community\n"
    "                      ? 'e.g. Grande Prairie'\n"
    "                      : widget.delivery\n"
    "                          ? 'e.g. Dawson Creek, British Columbia'\n"
    "                          : 'e.g. Grande Prairie, Alberta',\n"
    "                  helperText: widget.community\n"
    "                      ? 'Used to organize local marketplace and nearby search results.'\n"
    "                      : widget.delivery\n"
    "                          ? 'For a rural Tomslake destination, Dawson Creek may be the nearest well-known service town.'\n"
    "                          : null)),",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "                  labelText: widget.delivery\n"
    "                      ? 'Destination label *'\n"
    "                      : 'Public location label',\n"
    "                  hintText: widget.delivery\n"
    "                      ? 'e.g. Tomslake Farm — south gate'\n"
    "                      : 'e.g. 25 km west of Grande Prairie',\n"
    "                  helperText: widget.delivery\n"
    "                      ? 'Use a short name the buyer, seller and driver will recognize.'\n"
    "                      : null)),",
    "                  labelText: widget.community\n"
    "                      ? 'Public community label *'\n"
    "                      : widget.delivery\n"
    "                          ? 'Destination label *'\n"
    "                          : 'Public location label',\n"
    "                  hintText: widget.community\n"
    "                      ? 'e.g. Grande Prairie, Alberta'\n"
    "                      : widget.delivery\n"
    "                          ? 'e.g. Tomslake Farm — south gate'\n"
    "                          : 'e.g. 25 km west of Grande Prairie',\n"
    "                  helperText: widget.community\n"
    "                      ? 'Shown on your seller profile; the exact pin remains private.'\n"
    "                      : widget.delivery\n"
    "                          ? 'Use a short name the buyer, seller and driver will recognize.'\n"
    "                          : null)),",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "          else ...[\n"
    "            const Text('Who can see this location?',",
    "          else if (widget.community)\n"
    "            const Card(\n"
    "                color: Color(0xFFEAF4FD),\n"
    "                child: ListTile(\n"
    "                    leading:\n"
    "                        Icon(Icons.radar, color: Color(0xFF0878E8)),\n"
    "                    title: Text('Broad-area profile location'),\n"
    "                    subtitle: Text(\n"
    "                        'Pipe Buyer stores the exact pin privately and publishes only an approximate area for discovery.')))\n"
    "          else ...[\n"
    "            const Text('Who can see this location?',",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "                  labelText: widget.delivery\n"
    "                      ? 'Private delivery instructions'\n"
    "                      : 'Private access instructions',\n"
    "                  hintText: widget.delivery\n"
    "                      ? 'Gate, yard contact, unloading or appointment details'\n"
    "                      : 'Gate, lease road, appointment or loading details')),",
    "                  labelText: widget.community\n"
    "                      ? 'Private community notes'\n"
    "                      : widget.delivery\n"
    "                          ? 'Private delivery instructions'\n"
    "                          : 'Private access instructions',\n"
    "                  hintText: widget.community\n"
    "                      ? 'Optional notes for your own records'\n"
    "                      : widget.delivery\n"
    "                          ? 'Gate, yard contact, unloading or appointment details'\n"
    "                          : 'Gate, lease road, appointment or loading details')),",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "              label: Text(widget.delivery\n"
    "                  ? 'Use this destination'\n"
    "                  : 'Use this location')),",
    "              label: Text(widget.community\n"
    "                  ? 'Use this primary community'\n"
    "                  : widget.delivery\n"
    "                      ? 'Use this destination'\n"
    "                      : 'Use this location')),",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "  void _save() {\n"
    "    if (widget.delivery && _town.text.trim().isEmpty) {\n"
    "      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(\n"
    "          content: Text(\n"
    "              'Enter the nearest recognized town so drivers can orient the route.')));\n"
    "      return;\n"
    "    }\n"
    "    if (_publicName.text.trim().isEmpty) {\n"
    "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n"
    "          content: Text(widget.delivery\n"
    "              ? 'Enter a destination label drivers can recognize.'\n"
    "              : 'Enter a public location label.')));\n"
    "      return;\n"
    "    }",
    "  void _save() {\n"
    "    if ((widget.delivery || widget.community) &&\n"
    "        _town.text.trim().isEmpty) {\n"
    "      PipeFeedback.show(\n"
    "        context,\n"
    "        message: widget.community\n"
    "            ? 'Select or enter the city, town, or municipality for this profile.'\n"
    "            : 'Enter the nearest recognized town so drivers can orient the route.',\n"
    "        tone: PipeStatusTone.warning,\n"
    "      );\n"
    "      return;\n"
    "    }\n"
    "    if (_publicName.text.trim().isEmpty) {\n"
    "      PipeFeedback.show(\n"
    "        context,\n"
    "        message: widget.community\n"
    "            ? 'Enter a public community label, such as Grande Prairie, Alberta.'\n"
    "            : widget.delivery\n"
    "                ? 'Enter a destination label drivers can recognize.'\n"
    "                : 'Enter a public location label.',\n"
    "        tone: PipeStatusTone.warning,\n"
    "      );\n"
    "      return;\n"
    "    }",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "          visibility: widget.delivery ? LocationVisibility.exact : _visibility,",
    "          visibility: widget.delivery\n"
    "              ? LocationVisibility.exact\n"
    "              : widget.community\n"
    "                  ? LocationVisibility.approximate\n"
    "                  : _visibility,",
)
replace_once(
    "lib/marketplace/marketplace_location_picker.dart",
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(\n"
    "            SnackBar(content: Text('Could not use device location: $error')));\n"
    "      }\n"
    "    }",
    "    } catch (error) {\n"
    "      if (mounted) {\n"
    "        final denied = error is StateError;\n"
    "        PipeFeedback.show(\n"
    "          context,\n"
    "          message: denied\n"
    "              ? 'Location access was not granted. Search for the community or place instead.'\n"
    "              : 'Your device location could not be loaded. Search for the community or place instead.',\n"
    "          tone: PipeStatusTone.warning,\n"
    "        );\n"
    "      }\n"
    "    }",
)

# ---------------------------------------------------------------------------
# Tests and schema contracts.
# ---------------------------------------------------------------------------
(ROOT / "test/marketplace_profile_feedback_test.dart").write_text(
    """import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_profile_feedback.dart';

void main() {
  test('primary community has a specific incomplete-profile message', () {
    expect(
      incompleteProfileMessage(const ['Primary community']),
      'Please select your primary community on the map before continuing.',
    );
  });

  test('save errors never expose backend implementation wording', () {
    final message = profileOperationErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      fallback: 'Unable to save.',
    );
    expect(message.toLowerCase(), isNot(contains('firebase')));
    expect(message.toLowerCase(), isNot(contains('rules')));
    expect(message, contains('Refresh your sign-in'));
  });

  test('network failures provide a retryable connection message', () {
    final message = profileOperationErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      fallback: 'Unable to save.',
    );
    expect(message, contains('Check your connection'));
  });
}
""",
    encoding="utf-8",
)

(ROOT / "test/marketplace_profile_community_test.dart").write_text(
    """import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pipe_app/marketplace/marketplace_location.dart';
import 'package:pipe_app/marketplace/marketplace_profile_community.dart';

void main() {
  const location = MarketplaceLocation(
    point: LatLng(55.1707, -118.7947),
    visibility: LocationVisibility.exact,
    publicName: 'Grande Prairie, Alberta',
    address: 'Private street address',
    nearestTown: 'Grande Prairie',
    accessNotes: 'Private gate notes',
    region: 'Alberta',
    postalCode: 'T8V 0X9',
    country: 'Canada',
  );

  test('primary community keeps exact coordinates private', () {
    final privateData = primaryCommunityPrivateData(location, 'seller-1');
    final point = privateData['exactGeoPoint'] as GeoPoint;
    expect(point.latitude, 55.1707);
    expect(point.longitude, -118.7947);
    expect(privateData['fullAddress'], 'Private street address');
    expect(privateData['ownerUid'], 'seller-1');
  });

  test('primary community publishes only broad-area discovery data', () {
    final publicData = primaryCommunityPublicData(location);
    final point = publicData['publicGeoPoint'] as GeoPoint;
    expect(publicData['locationVisibility'], 'approximate');
    expect(point.latitude, 55.15);
    expect(point.longitude, -118.8);
    expect(publicData, isNot(contains('fullAddress')));
    expect(publicData, isNot(contains('accessNotes')));
  });
}
""",
    encoding="utf-8",
)

(ROOT / "test/marketplace_profile_persistence_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile persistence handles a missing private user document', () {
    final source = File(
      'lib/marketplace/marketplace_profile_repository.dart',
    ).readAsStringSync();
    expect(source, contains('runTransaction'));
    expect(source, contains("'userScore': 70"));
    expect(source, contains("'accountVerified': false"));
    expect(source, contains("'primaryCommunityLocation'"));
    expect(source, contains("'primaryCommunityGeoPoint'"));
  });

  test('profile page uses mapped community and safe feedback', () {
    final source =
        File('lib/marketplace/marketplace_profile_page.dart').readAsStringSync();
    expect(source, contains('Primary community'));
    expect(source, contains('showCommunity'));
    expect(source, contains('pendingPhoneE164'));
    expect(source, isNot(contains('Check Firebase rules')));
  });
}
""",
    encoding="utf-8",
)

replace_once(
    "firebase/rules-tests/firestore_rules.test.js",
    "  getDoc,\n  getDocs,\n  limit,",
    "  getDoc,\n  getDocs,\n  GeoPoint,\n  limit,",
)
append_once(
    "firebase/rules-tests/firestore_rules.test.js",
    'test("new personal profile baseline and mapped community are writable"',
    """
test("new personal profile baseline and mapped community are writable", async () => {
  const uid = "new-profile-user";
  const db = testEnvironment.authenticatedContext(uid).firestore();
  const updatedAt = Timestamp.fromDate(new Date("2026-08-06T00:00:00.000Z"));

  await assertSucceeds(setDoc(doc(db, "users", uid), {
    uid,
    accountType: "personal",
    userScore: 70,
    accountVerified: false,
    display_name: "New Seller",
    pendingPhoneE164: "+12507194015",
    baseCommunity: "Grande Prairie, Alberta",
    primaryCommunityLocation: {
      ownerUid: uid,
      exactGeoPoint: new GeoPoint(55.1707, -118.7947),
      fullAddress: "Private street address",
      nearestTown: "Grande Prairie",
      region: "Alberta",
      postalCode: "T8V 0X9",
      country: "Canada",
      accessNotes: "Private notes",
      visibility: "approximate",
      publicName: "Grande Prairie, Alberta",
      updatedAt,
    },
    sellerBio: "Oilfield marketplace seller and buyer.",
    preferredContact: "In-app message",
    personalProfileComplete: true,
    profileComplete: true,
    profileCompletion: 100,
    profileUpdatedAt: updatedAt,
  }));

  await assertSucceeds(setDoc(doc(db, "public_seller_profiles", uid), {
    ownerUid: uid,
    displayName: "New Seller",
    description: "Oilfield marketplace seller and buyer.",
    baseCommunity: "Grande Prairie, Alberta",
    primaryCommunity: {
      locationVisibility: "approximate",
      publicLocationName: "Grande Prairie, Alberta",
      nearestTown: "Grande Prairie",
      region: "Alberta",
      country: "Canada",
      approximateRadiusKm: 10,
      publicGeoPoint: new GeoPoint(55.15, -118.8),
    },
    primaryCommunityGeoPoint: new GeoPoint(55.15, -118.8),
    primaryCommunityTown: "Grande Prairie",
    primaryCommunityRegion: "Alberta",
    primaryCommunityCountry: "Canada",
    updatedAt,
  }));
});
""",
)
replace_once(
    "firebase/FIRESTORE_SCHEMA.md",
    "- `users/{uid}`: private personal account and contact preferences. Firebase\n"
    "  Auth email/phone claims are synchronized into protected ownership fields by\n"
    "  `syncAccountVerification`; clients cannot mark themselves verified.",
    "- `users/{uid}`: private personal account and contact preferences. Firebase\n"
    "  Auth email/phone claims are synchronized into protected ownership fields by\n"
    "  `syncAccountVerification`; clients cannot mark themselves verified. The\n"
    "  private `primaryCommunityLocation` map stores the exact profile pin, full\n"
    "  address, and private notes for the owner only.",
)
replace_once(
    "firebase/FIRESTORE_SCHEMA.md",
    "- `public_seller_profiles/{uid}`: public discovery index containing approved tag IDs and account type.",
    "- `public_seller_profiles/{uid}`: public discovery index containing approved\n"
    "  tag IDs, account type, the legacy `baseCommunity` label, and a structured\n"
    "  `primaryCommunity` broad-area map. `primaryCommunityGeoPoint`, town, region,\n"
    "  and country fields support nearby discovery without exposing the private\n"
    "  exact profile pin or address.",
)

print("Applied profile primary-community persistence remediation.")
