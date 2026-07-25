import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'marketplace_command_client.dart';

class MarketplaceAccountDeviceRepository {
  MarketplaceAccountDeviceRepository({
    MarketplaceCommandClient? commands,
    FirebaseAuth? auth,
  }) : _commands = commands ?? MarketplaceCommandClient(),
       _auth = auth ?? FirebaseAuth.instance;

  static const _installationKey = 'pipe_account_installation_id_v1';
  final MarketplaceCommandClient _commands;
  final FirebaseAuth _auth;

  Future<String> installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationKey)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final created = const Uuid().v4().toLowerCase();
    final saved = await preferences.setString(_installationKey, created);
    if (!saved) {
      throw StateError('This device could not save its account identifier.');
    }
    return created;
  }

  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  String get label {
    if (kIsWeb) return 'Web browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android device',
      TargetPlatform.iOS => 'iPhone or iPad',
      TargetPlatform.windows => 'Windows computer',
      TargetPlatform.macOS => 'Mac computer',
      TargetPlatform.linux => 'Linux computer',
      _ => 'Pipe Buyer device',
    };
  }

  Future<String?> registerCurrentDevice() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return null;
    final id = await installationId();
    final result = await _commands.execute('registerAccountDevice', {
      'deviceId': id,
      'label': label,
      'platform': platform,
    });
    final documentId = '${result['deviceDocumentId'] ?? ''}'.trim();
    if (documentId.isEmpty) {
      throw StateError('The server did not return the device record.');
    }
    return documentId;
  }

  Future<String?> currentDeviceDocumentId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final id = await installationId();
    return sha256.convert(utf8.encode('$uid|$id')).toString();
  }
}
