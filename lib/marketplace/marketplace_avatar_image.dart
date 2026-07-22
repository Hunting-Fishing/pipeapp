import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class MarketplaceAvatarImage extends StatelessWidget {
  const MarketplaceAvatarImage({
    super.key,
    required this.photoUrl,
    required this.size,
    required this.fallback,
  });

  final String photoUrl;
  final double size;
  final Widget fallback;
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
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: ClipOval(
          child: FutureBuilder<Uint8List?>(
              future: loadBytes(photoUrl),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes != null) {
                  return Image.memory(bytes,
                      key: ValueKey(photoUrl), fit: BoxFit.cover);
                }
                if (snapshot.connectionState != ConnectionState.done &&
                    photoUrl.startsWith('http')) {
                  return const ColoredBox(
                      color: Color(0xFFE5F2FF),
                      child: Center(
                          child: SizedBox.square(
                              dimension: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))));
                }
                return ColoredBox(
                    color: const Color(0xFFE5F2FF),
                    child: Center(child: fallback));
              })));
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
          return Image.memory(bytes, key: ValueKey(url), fit: fit);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
              color: Color(0xFFE5F2FF),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return fallback;
      });
}

class MarketplaceUserAvatar extends StatefulWidget {
  const MarketplaceUserAvatar({
    super.key,
    required this.userUid,
    required this.size,
    required this.fallback,
    this.photoUrl = '',
  });

  final String userUid;
  final double size;
  final Widget fallback;
  final String photoUrl;

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
          fallback: widget.fallback));
}
