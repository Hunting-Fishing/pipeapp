import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceAvatarImage extends StatelessWidget {
  const MarketplaceAvatarImage({
    super.key,
    required this.photoUrl,
    required this.size,
    required this.fallback,
    this.verified = false,
    this.business = false,
    this.borderColor,
  });

  final String photoUrl;
  final double size;
  final Widget fallback;
  final bool verified;
  final bool business;
  final Color? borderColor;

  static final Map<String, Uint8List> _byteCache = {};
  static final Map<String, Future<Uint8List?>> _requestCache = {};

  static Future<Uint8List?> loadBytes(String photoUrl) async {
    if (!photoUrl.startsWith('http')) return null;
    final cached = _byteCache[photoUrl];
    if (cached != null) return cached;
    return _requestCache.putIfAbsent(photoUrl, () => _download(photoUrl));
  }

  static Future<Uint8List?> _download(String photoUrl) async {
    try {
      final bytes = await FirebaseStorage.instance
          .refFromURL(photoUrl)
          .getData(10 * 1024 * 1024)
          .timeout(const Duration(seconds: 12));
      if (bytes != null) _byteCache[photoUrl] = bytes;
      return bytes;
    } catch (_) {
      _requestCache.remove(photoUrl);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = borderColor ??
        (verified
            ? PipeBuyerColors.success
            : business
                ? PipeBuyerColors.orange
                : Theme.of(context).dividerColor);
    final innerSize = (size - 4).clamp(0, size).toDouble();
    final businessRadius = BorderRadius.circular((size * .22).clamp(10, 18));

    Widget clipIdentity(Widget child) => business
        ? ClipRRect(borderRadius: businessRadius, child: child)
        : ClipOval(child: child);

    final frameDecoration = BoxDecoration(
      shape: business ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: business ? businessRadius : null,
      color: Theme.of(context).cardColor,
      border: Border.all(color: ring, width: verified ? 2.5 : 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    );

    return Semantics(
      image: true,
      label: business
          ? 'Business profile image${verified ? ', verified' : ''}'
          : 'User profile image${verified ? ', verified' : ''}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: frameDecoration,
                child: clipIdentity(
                  SizedBox.square(
                    dimension: innerSize,
                    child: FutureBuilder<Uint8List?>(
                      future: loadBytes(photoUrl),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes != null) {
                          return Image.memory(
                            bytes,
                            key: ValueKey(photoUrl),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          );
                        }
                        if (snapshot.connectionState != ConnectionState.done &&
                            photoUrl.startsWith('http')) {
                          return _AvatarSurface(
                            business: business,
                            child: const Center(
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return _AvatarSurface(
                          business: business,
                          child: Center(child: fallback),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (business)
              Positioned(
                left: 5,
                top: 5,
                child: Container(
                  width: size >= 64 ? 22 : 18,
                  height: size >= 64 ? 22 : 18,
                  decoration: BoxDecoration(
                    color: const Color(0xE6111820),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    Icons.business_outlined,
                    color: PipeBuyerColors.orange,
                    size: size >= 64 ? 13 : 10,
                  ),
                ),
              ),
            if (verified)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size >= 56 ? 22 : 18,
                  height: size >= 56 ? 22 : 18,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: size >= 56 ? 14 : 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSurface extends StatelessWidget {
  const _AvatarSurface({required this.business, required this.child});

  final bool business;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: business
                ? const [
                    PipeBuyerColors.orangeSoft,
                    Color(0xFFFFF8F1),
                  ]
                : const [
                    Color(0xFFF1F4F7),
                    Color(0xFFE7EBF0),
                  ],
          ),
        ),
        child: child,
      );
}

class MarketplaceStorageMediaImage extends StatelessWidget {
  const MarketplaceStorageMediaImage({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
  });

  final String url;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: MarketplaceAvatarImage.loadBytes(url),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Image.memory(
                bytes,
                key: ValueKey(url),
                fit: fit,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PipeBuyerColors.ink,
                    PipeBuyerColors.graphite,
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: -30,
                    top: -38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x1FFF6A00),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 130),
                    ),
                  ),
                  const SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: PipeBuyerColors.orange,
                    ),
                  ),
                ],
              ),
            );
          }
          return fallback;
        },
      );
}

class MarketplaceUserAvatar extends StatefulWidget {
  const MarketplaceUserAvatar({
    super.key,
    required this.userUid,
    required this.size,
    required this.fallback,
    this.photoUrl = '',
    this.verified = false,
    this.business = false,
  });

  final String userUid;
  final double size;
  final Widget fallback;
  final String photoUrl;
  final bool verified;
  final bool business;

  @override
  State<MarketplaceUserAvatar> createState() => _MarketplaceUserAvatarState();
}

class _MarketplaceUserAvatarState extends State<MarketplaceUserAvatar> {
  late Future<String> _photoUrlFuture;

  @override
  void initState() {
    super.initState();
    _photoUrlFuture = _photoUrl();
  }

  @override
  void didUpdateWidget(covariant MarketplaceUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userUid != widget.userUid ||
        oldWidget.photoUrl != widget.photoUrl) {
      _photoUrlFuture = _photoUrl();
    }
  }

  Future<String> _photoUrl() async {
    if (widget.photoUrl.startsWith('http')) return widget.photoUrl;
    if (widget.userUid.isEmpty) return '';
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser?.uid == widget.userUid &&
        (authUser?.photoURL ?? '').startsWith('http')) {
      return authUser!.photoURL!;
    }
    final firestore = FirebaseFirestore.instance;
    final profiles = await Future.wait([
      firestore
          .collection('public_business_profiles')
          .doc(widget.userUid)
          .get()
          .timeout(const Duration(seconds: 6))
          .then<Map<String, dynamic>?>((value) => value.data())
          .catchError((_) => null),
      firestore
          .collection('public_seller_profiles')
          .doc(widget.userUid)
          .get()
          .timeout(const Duration(seconds: 6))
          .then<Map<String, dynamic>?>((value) => value.data())
          .catchError((_) => null),
    ]);
    for (final profile in profiles) {
      final url =
          '${profile?['photoUrl'] ?? profile?['avatarUrl'] ?? profile?['photo_url'] ?? ''}'
              .trim();
      if (url.startsWith('http')) return url;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _photoUrlFuture,
        builder: (context, snapshot) => MarketplaceAvatarImage(
          photoUrl: snapshot.data ?? '',
          size: widget.size,
          fallback: widget.fallback,
          verified: widget.verified,
          business: widget.business,
        ),
      );
}
