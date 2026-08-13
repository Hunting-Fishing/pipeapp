import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

class MarketplaceListingActivity {
  const MarketplaceListingActivity({
    this.views = 0,
    this.saves = 0,
    this.shares = 0,
    this.likes = 0,
    this.offers = 0,
  });

  final int views;
  final int saves;
  final int shares;
  final int likes;
  final int offers;

  String get label => [
        _countLabel(views, 'view'),
        _countLabel(saves, 'save'),
        _countLabel(shares, 'share'),
        _countLabel(likes, 'like'),
        _countLabel(offers, 'offer'),
      ].join(' • ');
}

String _countLabel(int value, String noun) =>
    '$value $noun${value == 1 ? '' : 's'}';

String marketplacePublicLocationLabel({
  required String publicName,
  required String nearestTown,
  required String region,
  required String country,
}) {
  final parts = <String>[];
  void add(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return;
    final normalized = candidate.toLowerCase();
    if (parts.any((part) {
      final existing = part.toLowerCase();
      final regionCode = _canadianRegionCodes[normalized];
      final regionCodePattern = regionCode == null
          ? null
          : RegExp('(?:^|[,\\s])${RegExp.escape(regionCode)}(?:[,\\s]|\$)',
              caseSensitive: false);
      return existing == normalized ||
          existing.contains(normalized) ||
          (regionCodePattern?.hasMatch(part) ?? false);
    })) {
      return;
    }
    parts.add(candidate);
  }

  add(publicName);
  add(nearestTown);
  add(region);
  add(country);
  return parts.isEmpty ? 'Location available by request' : parts.join(', ');
}

const _canadianRegionCodes = <String, String>{
  'alberta': 'AB',
  'british columbia': 'BC',
  'manitoba': 'MB',
  'new brunswick': 'NB',
  'newfoundland and labrador': 'NL',
  'northwest territories': 'NT',
  'nova scotia': 'NS',
  'nunavut': 'NU',
  'ontario': 'ON',
  'prince edward island': 'PE',
  'quebec': 'QC',
  'saskatchewan': 'SK',
  'yukon': 'YT',
};

double marketplaceDistanceKm(LatLng from, LatLng to) {
  const earthRadiusKm = 6371.0088;
  double radians(double degrees) => degrees * math.pi / 180;
  final latitudeDelta = radians(to.latitude - from.latitude);
  final longitudeDelta = radians(to.longitude - from.longitude);
  final startLatitude = radians(from.latitude);
  final endLatitude = radians(to.latitude);
  final haversine = math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(startLatitude) *
          math.cos(endLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusKm *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

String marketplaceDistanceLabel({
  required LatLng viewer,
  required LatLng listing,
  String viewerLabel = '',
  bool approximate = true,
}) {
  final distance = marketplaceDistanceKm(viewer, listing);
  final rounded = distance < 10
      ? distance.round()
      : distance < 100
          ? (distance / 5).round() * 5
          : (distance / 10).round() * 10;
  final origin =
      viewerLabel.trim().isEmpty ? '' : ' from ${viewerLabel.trim()}';
  return '${approximate ? 'About ' : ''}$rounded km$origin';
}

@immutable
class MarketplaceViewerCommunity {
  const MarketplaceViewerCommunity({required this.point, required this.label});

  final LatLng point;
  final String label;
}

MarketplaceViewerCommunity? marketplaceViewerCommunityFromData({
  Map<String, dynamic>? user,
  Map<String, dynamic>? publicSeller,
  Map<String, dynamic>? privateBusiness,
}) {
  MarketplaceViewerCommunity? readPoint(
    dynamic value,
    String label,
  ) {
    if (value is GeoPoint) {
      return MarketplaceViewerCommunity(
        point: LatLng(value.latitude, value.longitude),
        label: label.trim(),
      );
    }
    return null;
  }

  final personal = user?['primaryCommunityLocation'];
  if (personal is Map) {
    final data = Map<String, dynamic>.from(personal);
    final result = readPoint(
      data['exactGeoPoint'] ?? data['publicGeoPoint'],
      '${data['publicName'] ?? data['nearestTown'] ?? user?['baseCommunity'] ?? ''}',
    );
    if (result != null) return result;
  }

  final yard = privateBusiness?['yardLocation'];
  if (yard is Map) {
    final data = Map<String, dynamic>.from(yard);
    final result = readPoint(
      data['exactGeoPoint'] ?? data['publicGeoPoint'],
      '${data['publicName'] ?? data['nearestTown'] ?? ''}',
    );
    if (result != null) return result;
  }

  return readPoint(
    publicSeller?['primaryCommunityGeoPoint'],
    '${publicSeller?['baseCommunity'] ?? publicSeller?['primaryCommunityTown'] ?? ''}',
  );
}

class MarketplaceViewerLocationScope extends StatefulWidget {
  const MarketplaceViewerLocationScope({required this.child, super.key});

  final Widget child;

  static MarketplaceViewerCommunity? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_MarketplaceViewerLocation>()
      ?.community;

  @override
  State<MarketplaceViewerLocationScope> createState() =>
      _MarketplaceViewerLocationScopeState();
}

class _MarketplaceViewerLocationScopeState
    extends State<MarketplaceViewerLocationScope> {
  MarketplaceViewerCommunity? _community;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _sellerSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _businessSubscription;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _publicSeller;
  Map<String, dynamic>? _privateBusiness;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_load);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    _sellerSubscription?.cancel();
    _businessSubscription?.cancel();
    super.dispose();
  }

  void _load(User? user) {
    final generation = ++_generation;
    _userSubscription?.cancel();
    _sellerSubscription?.cancel();
    _businessSubscription?.cancel();
    _user = null;
    _publicSeller = null;
    _privateBusiness = null;
    if (user == null) {
      if (mounted) setState(() => _community = null);
      return;
    }
    final firestore = FirebaseFirestore.instance;
    _userSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      _user = snapshot.data();
      _updateCommunity(generation);
    }, onError: (_) => _updateCommunity(generation));
    _sellerSubscription = firestore
        .collection('public_seller_profiles')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      _publicSeller = snapshot.data();
      _updateCommunity(generation);
    }, onError: (_) => _updateCommunity(generation));
    _businessSubscription = firestore
        .collection('business_private')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      _privateBusiness = snapshot.data();
      _updateCommunity(generation);
    }, onError: (_) => _updateCommunity(generation));
  }

  void _updateCommunity(int generation) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _community = marketplaceViewerCommunityFromData(
        user: _user,
        publicSeller: _publicSeller,
        privateBusiness: _privateBusiness,
      );
    });
  }

  @override
  Widget build(BuildContext context) => _MarketplaceViewerLocation(
        community: _community,
        child: widget.child,
      );
}

class _MarketplaceViewerLocation extends InheritedWidget {
  const _MarketplaceViewerLocation({
    required this.community,
    required super.child,
  });

  final MarketplaceViewerCommunity? community;

  @override
  bool updateShouldNotify(_MarketplaceViewerLocation oldWidget) =>
      oldWidget.community != community;
}
