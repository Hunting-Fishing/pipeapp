import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_profile_repository.dart';
import 'marketplace_profile_tags.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_service_area.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';
import 'marketplace_auth_page.dart';
import 'open_address_autocomplete.dart';
import 'profile_photo_picker.dart';
import 'profile_photo_uploader.dart';
import 'regional_phone_field.dart';

class MarketplaceProfilePage extends StatefulWidget {
  const MarketplaceProfilePage({
    super.key,
    this.onboarding = false,
    this.initialAccountType = 'personal',
  });

  final bool onboarding;
  final String initialAccountType;

  @override
  State<MarketplaceProfilePage> createState() => _MarketplaceProfilePageState();
}

IconData _preferredContactIcon(String value) => switch (value) {
      'In-app message' => Icons.chat_bubble_outline,
      'Phone' => Icons.phone_outlined,
      'Email' => Icons.email_outlined,
      'Text message' => Icons.sms_outlined,
      _ => Icons.contact_phone_outlined,
    };

class _MarketplaceProfilePageState extends State<MarketplaceProfilePage> {
  final _repo = MarketplaceProfileRepository();
  final _personalKey = GlobalKey<FormState>();
  final _businessKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  final _community = TextEditingController();
  final _personalBio = TextEditingController();
  final _businessName = TextEditingController();
  final _legalBusinessName = TextEditingController();
  final _businessPhone = TextEditingController();
  final _businessEmail = TextEditingController();
  final _website = TextEditingController();
  final _serviceArea = TextEditingController();
  final _businessAddress = TextEditingController();
  final _businessBio = TextEditingController();
  final _personalScroll = ScrollController();
  final _businessScroll = ScrollController();
  final _displayNameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _communityKey = GlobalKey();
  final _personalBioKey = GlobalKey();
  final _businessNameKey = GlobalKey();
  final _legalNameKey = GlobalKey();
  final _businessPhoneKey = GlobalKey();
  final _businessEmailKey = GlobalKey();
  final _websiteKey = GlobalKey();
  final _serviceAreaKey = GlobalKey();
  final _businessAddressKey = GlobalKey();
  final _businessBioKey = GlobalKey();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _avatarTransferStarted = false;
  double _avatarUploadProgress = 0;
  String _avatarUploadStage = '';
  String _photoUrl = '';
  Uint8List? _avatarBytes;
  String _preferredContact = 'In-app message';
  String _accountType = 'personal';
  String _accountEmail = '';
  MarketplaceServiceArea? _serviceAreaSelection;
  MarketplaceLocation? _businessYardLocation;
  Timer? _completionDebounce;
  List<Map<String, dynamic>> _savedLocations = const [];
  StreamSubscription<User?>? _authSubscription;
  final List<String> _loadIssues = [];
  bool _loadInProgress = false;
  bool _profileSourceLoaded = false;

  @override
  void initState() {
    super.initState();
    _accountType =
        widget.initialAccountType == 'business' ? 'business' : 'personal';
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
      } else {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await _loadProfileData();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    Map<String, dynamic>? personal;
    Map<String, dynamic>? publicSeller;
    Map<String, dynamic>? publicBusiness;
    Map<String, dynamic>? privateBusiness;
    _loadIssues.clear();
    try {
      await user.getIdToken();
    } catch (_) {
      _loadIssues.add('Secure account session');
    }
    try {
      personal = await _repo.loadPersonal();
      _profileSourceLoaded = true;
    } catch (_) {
      _loadIssues.add('Personal details');
    }
    try {
      publicSeller = await _repo.loadPublicSeller();
    } catch (_) {
      _loadIssues.add('Public seller profile');
    }
    try {
      publicBusiness = await _repo.loadPublicBusiness();
    } catch (_) {
      _loadIssues.add('Business details');
    }
    try {
      privateBusiness = await _repo.loadPrivateBusiness();
    } catch (_) {
      _loadIssues.add('Private business details');
    }
    try {
      _savedLocations = await _repo.loadSavedLocations();
    } catch (_) {
      _savedLocations = const [];
      _loadIssues.add('Saved locations');
    }
    if (personal != null) {
      _accountType = '${personal['accountType'] ?? widget.initialAccountType}';
      if (_accountType != 'business') _accountType = 'personal';
      _accountEmail = '${personal['email'] ?? user.email ?? ''}';
      _displayName.text =
          '${personal['display_name'] ?? publicSeller?['displayName'] ?? ''}';
      _phone.text = '${personal['phone_number'] ?? ''}';
      _community.text =
          '${personal['baseCommunity'] ?? publicSeller?['baseCommunity'] ?? ''}';
      _personalBio.text =
          '${personal['sellerBio'] ?? publicSeller?['description'] ?? ''}';
      _preferredContact = '${personal['preferredContact'] ?? 'In-app message'}';
    } else {
      _accountEmail = user.email ?? _accountEmail;
      if (publicSeller != null) {
        _displayName.text =
            '${publicSeller['displayName'] ?? _displayName.text}';
        _community.text = '${publicSeller['baseCommunity'] ?? _community.text}';
        _personalBio.text =
            '${publicSeller['description'] ?? _personalBio.text}';
      }
    }
    final avatarUrl = _safeMediaUrl(personal?['photo_url'] ??
        publicBusiness?['photoUrl'] ??
        publicSeller?['photoUrl'] ??
        user.photoURL);
    if (avatarUrl.isNotEmpty) _photoUrl = avatarUrl;
    if (publicBusiness != null) {
      _businessName.text = '${publicBusiness['publicName'] ?? ''}';
      _businessPhone.text = '${publicBusiness['publicPhone'] ?? ''}';
      _businessEmail.text = '${publicBusiness['publicEmail'] ?? ''}';
      _website.text = '${publicBusiness['website'] ?? ''}';
      _businessBio.text = '${publicBusiness['description'] ?? ''}';
    }
    if (privateBusiness != null) {
      _legalBusinessName.text = '${privateBusiness['legalName'] ?? ''}';
      _businessAddress.text = '${privateBusiness['privateAddress'] ?? ''}';
    }
    final serviceArea = publicBusiness?['serviceArea'];
    if (serviceArea is Map) {
      try {
        _serviceAreaSelection = MarketplaceServiceArea.fromMap(
            Map<String, dynamic>.from(serviceArea));
        _serviceArea.text = _serviceAreaSelection!.summary;
      } catch (_) {
        _serviceArea.text = '${publicBusiness?['serviceAreaLabel'] ?? ''}';
        _loadIssues.add('Service-area map');
      }
    } else if (publicBusiness != null) {
      _serviceArea.text =
          '${publicBusiness['serviceAreaLabel'] ?? serviceArea ?? ''}';
    }
    final yardLocation = privateBusiness?['yardLocation'];
    if (yardLocation is Map) {
      try {
        _businessYardLocation = MarketplaceLocation.fromPrivateData(
            Map<String, dynamic>.from(yardLocation));
      } catch (_) {
        _loadIssues.add('Yard map pin');
      }
    }
    if (_profileSourceLoaded) {
      _scheduleCompletionSync(immediate: true);
    }
    if ((personal?['roleVersion'] as num?)?.toInt() != 1) {
      _repo.requestRoleSync(_accountType).catchError((_) {});
    }
    if (mounted) setState(() => _loading = false);
    if (_photoUrl.isNotEmpty) {
      try {
        final bytes = await FirebaseStorage.instance
            .refFromURL(_photoUrl)
            .getData(10 * 1024 * 1024);
        if (mounted) setState(() => _avatarBytes = bytes);
      } catch (_) {
        if (mounted) setState(() => _avatarBytes = null);
      }
    }
  }

  @override
  void dispose() {
    _completionDebounce?.cancel();
    _authSubscription?.cancel();
    _personalScroll.dispose();
    _businessScroll.dispose();
    for (final controller in [
      _displayName,
      _phone,
      _community,
      _personalBio,
      _businessName,
      _legalBusinessName,
      _businessPhone,
      _businessEmail,
      _website,
      _serviceArea,
      _businessAddress,
      _businessBio
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (FirebaseAuth.instance.currentUser == null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 52),
          const SizedBox(height: 12),
          const Text('Sign in to create your seller profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MarketplaceAuthPage()));
                if (mounted) _load();
              },
              child: const Text('Sign in or create account')),
        ]),
      ));
    }
    final business = _accountType == 'business';
    final activeScroll = business ? _businessScroll : _personalScroll;
    final content = Scrollbar(
        controller: activeScroll,
        child: ListView(
            controller: activeScroll,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              const Text('Seller profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (_loadIssues.isNotEmpty) _profileLoadWarning(),
              Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFDDE5EE)),
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(children: [
                    _accountTypeBanner(),
                    _avatarSection(),
                    const Divider(height: 1),
                    _completionCard(),
                    const Divider(height: 1),
                    _profileDetailsHeader(),
                    business ? _businessForm() : _personalForm(),
                  ])),
            ]));
    if (!widget.onboarding) return content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _profileLoadWarning() => Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFFFF4E5),
      child: ListTile(
          leading:
              const Icon(Icons.sync_problem_outlined, color: Colors.deepOrange),
          title: const Text('Some profile sections need to reload',
              style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(_loadIssues.join(', ')),
          trailing: TextButton(
              onPressed: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: const Text('Retry'))));

  int get _profileCompletion {
    final fields = _accountType == 'business'
        ? [
            _businessName.text,
            _legalBusinessName.text,
            _businessPhone.text,
            _businessEmail.text,
            _website.text,
            _serviceAreaSelection == null ? '' : 'selected',
            _businessAddress.text,
            _businessBio.text,
          ]
        : [
            _displayName.text,
            _phone.text,
            _community.text,
            _personalBio.text,
          ];
    return ((fields.where((value) => value.trim().isNotEmpty).length /
                fields.length) *
            100)
        .round();
  }

  String _safeMediaUrl(Object? value) {
    final url = '${value ?? ''}'.trim();
    if (url.isEmpty ||
        url.toLowerCase().contains('error') ||
        !(url.startsWith('https://') || url.startsWith('http://'))) {
      return '';
    }
    return url;
  }

  Widget _avatarSection() {
    final name =
        (_accountType == 'business' ? _businessName.text : _displayName.text)
            .trim();
    return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          InkWell(
              customBorder: const CircleBorder(),
              onTap: _photoUrl.isEmpty ? _chooseAvatar : _viewAvatar,
              child: Hero(
                  tag: 'my-marketplace-avatar',
                  child: CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFE5F2FF),
                      child: ClipOval(
                          child: _avatarBytes != null
                              ? Image.memory(_avatarBytes!,
                                  key: ValueKey(_photoUrl),
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover)
                              : _photoUrl.isEmpty
                                  ? Center(
                                      child: Text(
                                          name.isEmpty
                                              ? '?'
                                              : name[0].toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.w900)))
                                  : Image.network(_photoUrl,
                                      key: ValueKey(_photoUrl),
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                          child: Text(name.isEmpty
                                              ? '?'
                                              : name[0].toUpperCase()))))))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Profile photo',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const Text('Shown with your listings, offers and messages.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF66758A))),
                const SizedBox(height: 7),
                OutlinedButton.icon(
                    onPressed: _uploadingAvatar ? null : _chooseAvatar,
                    icon: _uploadingAvatar
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo_outlined),
                    label: Text(_photoUrl.isEmpty
                        ? 'Add profile photo'
                        : 'Change photo')),
                if (_uploadingAvatar) ...[
                  const SizedBox(height: 8),
                  if (_avatarTransferStarted) ...[
                    LinearProgressIndicator(value: _avatarUploadProgress),
                    const SizedBox(height: 3),
                  ],
                  Text(_avatarUploadStage,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ]
              ]))
        ]));
  }

  Widget _profileDetailsHeader() {
    final business = _accountType == 'business';
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FF),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(
                  business ? Icons.business_outlined : Icons.badge_outlined,
                  color: const Color(0xFF087BEA))),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    business
                        ? 'Business profile details'
                        : 'Personal profile details',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                Text(
                    business
                        ? 'Manage the business information shown across the app'
                        : 'Manage the personal information shown across the app',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF66758A))),
              ])),
        ]));
  }

  Future<void> _chooseAvatar() async {
    if (_uploadingAvatar) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign in before adding a profile photo.')));
      return;
    }
    setState(() {
      _uploadingAvatar = true;
      _avatarTransferStarted = false;
      _avatarUploadProgress = 0;
      _avatarUploadStage = 'Select a photo from your device';
    });
    try {
      final bytes = await pickProfilePhotoBytes();
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No profile photo was selected.')));
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        throw StateError('Profile photos must be smaller than 10 MB.');
      }
      setState(() => _avatarUploadStage = 'Preparing photo preview');
      final cropped = await _prepareAvatar(bytes);
      if (cropped == null || !mounted) return;
      if (cropped.length > 10 * 1024 * 1024) {
        throw StateError(
            'The prepared profile photo is larger than 10 MB. Reduce the zoom or choose another image.');
      }
      final url = await _uploadAvatarBytes(cropped);
      if (!mounted) return;
      setState(() {
        _avatarUploadStage = 'Saving photo to your profile';
        _avatarUploadProgress = 1;
      });
      await _repo.saveAvatarUrl(url);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _avatarBytes = cropped;
        _avatarUploadProgress = 1;
      });
      PipeFeedback.show(
        context,
        message: 'Profile photo updated.',
        tone: PipeStatusTone.success,
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: _avatarFirebaseError(error),
          tone: PipeStatusTone.error,
        );
      }
    } on ProfilePhotoUploadException catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: _avatarTransportError(error),
          tone: PipeStatusTone.error,
        );
      }
    } on MissingPluginException {
      if (mounted) {
        PipeFeedback.show(
          context,
          message:
              'Photo chooser is unavailable. Refresh the app and try again.',
          tone: PipeStatusTone.error,
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: error.code == 'photo_access_denied'
              ? 'Photo access was denied. Allow photo access and try again.'
              : 'The photo could not be opened. Please try another image.',
          tone: PipeStatusTone.error,
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : _avatarTransferStarted
                ? 'The photo upload did not finish. Check your connection and try again.'
                : 'The profile photo could not be prepared. Please try another image.';
        PipeFeedback.show(
          context,
          message: message,
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
          _avatarTransferStarted = false;
          _avatarUploadStage = '';
        });
      }
    }
  }

  Future<String> _uploadAvatarBytes(Uint8List bytes) async {
    final activeUser = FirebaseAuth.instance.currentUser;
    if (activeUser == null) {
      throw FirebaseException(
          plugin: 'firebase_storage', code: 'unauthenticated');
    }
    ProfilePhotoUploadException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final idToken = await activeUser.getIdToken(true);
        if (idToken == null || idToken.isEmpty) {
          throw const ProfilePhotoUploadException('unauthenticated',
              'Your sign-in session could not be refreshed.');
        }
        if (!mounted) throw StateError('Profile page was closed.');
        setState(() {
          _avatarTransferStarted = true;
          _avatarUploadProgress = 0;
          _avatarUploadStage = attempt == 0
              ? 'Starting secure upload'
              : 'Retrying secure upload';
        });
        return await uploadProfilePhoto(
          bytes: bytes,
          userId: activeUser.uid,
          idToken: idToken,
          storageBucket: FirebaseStorage.instance.ref().bucket,
          onProgress: (value) {
            if (!mounted) return;
            final progress = value.clamp(0.0, 1.0);
            setState(() {
              _avatarUploadProgress = progress;
              _avatarUploadStage =
                  'Uploading photo • ${(progress * 100).round()}%';
            });
          },
        );
      } on ProfilePhotoUploadException catch (error) {
        lastError = error;
        if (attempt == 1 || !_retryableAvatarError(error.code)) rethrow;
        if (mounted) {
          setState(() {
            _avatarUploadProgress = 0;
            _avatarUploadStage = 'Refreshing connection before retry';
          });
        }
      }
    }
    throw lastError ??
        const ProfilePhotoUploadException(
            'unknown', 'The profile photo upload failed.');
  }

  bool _retryableAvatarError(String code) => const {
        'unauthenticated',
        'unauthorized',
        'retry-limit-exceeded',
        'network-error',
        'timeout',
        'unknown',
      }.contains(code);

  String _avatarTransportError(ProfilePhotoUploadException error) {
    switch (error.code) {
      case 'unauthenticated':
      case '401':
        return 'Your sign-in session expired. Sign in again and retry the photo.';
      case 'unauthorized':
      case 'permission-denied':
      case '403':
        return 'Your account is not authorized to save this photo.';
      case 'network-error':
        return 'The browser could not reach photo storage. Check the connection and try again.';
      case 'timeout':
        return 'The photo upload timed out after 90 seconds. Check the connection and try again.';
      case 'quota-exceeded':
      case '429':
        return 'Profile photo storage is temporarily at capacity. Please try again later.';
      default:
        return '${error.message} (${error.code})';
    }
  }

  String _avatarFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Your sign-in session expired. Sign in again and retry the photo.';
      case 'unauthorized':
      case 'permission-denied':
        return 'Your account is not authorized to save this photo. Refresh your sign-in and try again.';
      case 'quota-exceeded':
        return 'Profile photo storage is temporarily unavailable. Please try again later.';
      case 'retry-limit-exceeded':
      case 'canceled':
        return 'The photo upload was interrupted. Check your connection and try again.';
      default:
        return 'Profile photo upload failed (${error.code}). Please try again.';
    }
  }

  Future<Uint8List?> _prepareAvatar(Uint8List bytes) async {
    final previewKey = GlobalKey();
    final transform = TransformationController();
    var zoom = 1.0;
    void setZoom(double requested, StateSetter updateDialog) {
      final value = requested.clamp(.2, 4.0);
      final translation = transform.value.getTranslation();
      transform.value = Matrix4.identity()
        ..translateByDouble(translation.x, translation.y, 0, 1)
        ..scaleByDouble(value, value, value, 1);
      updateDialog(() => zoom = value);
    }

    return showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, updateDialog) => AlertDialog(
                    title: const Text('Position your profile photo'),
                    content: SizedBox(
                        width: 380,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'Drag the photo itself to position it. Pinch or use the slider to shrink and enlarge it. The circle below is exactly what will be saved.'),
                          const SizedBox(height: 16),
                          Container(
                              width: 244,
                              height: 244,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0878E8)),
                              child: RepaintBoundary(
                                  key: previewKey,
                                  child: ClipOval(
                                      child: ColoredBox(
                                          color: const Color(0xFFE5F2FF),
                                          child: InteractiveViewer(
                                              transformationController:
                                                  transform,
                                              minScale: .2,
                                              maxScale: 4,
                                              boundaryMargin:
                                                  const EdgeInsets.all(260),
                                              onInteractionUpdate: (_) {
                                                final scale = transform.value
                                                    .getMaxScaleOnAxis();
                                                updateDialog(() =>
                                                    zoom = scale.clamp(.2, 4));
                                              },
                                              child: SizedBox.square(
                                                  dimension: 236,
                                                  child: Image.memory(bytes,
                                                      fit:
                                                          BoxFit.contain))))))),
                          const SizedBox(height: 12),
                          Row(children: [
                            IconButton.filledTonal(
                                tooltip: 'Zoom out',
                                onPressed: () =>
                                    setZoom(zoom - .1, updateDialog),
                                icon: const Icon(Icons.remove)),
                            Expanded(
                                child: Slider(
                                    value: zoom,
                                    min: .2,
                                    max: 4,
                                    label: '${zoom.toStringAsFixed(1)}×',
                                    onChanged: (value) =>
                                        setZoom(value, updateDialog))),
                            IconButton.filledTonal(
                                tooltip: 'Zoom in',
                                onPressed: () =>
                                    setZoom(zoom + .1, updateDialog),
                                icon: const Icon(Icons.add)),
                          ]),
                          Text('${zoom.toStringAsFixed(1)}× zoom',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                              onPressed: () {
                                transform.value = Matrix4.identity();
                                updateDialog(() => zoom = 1);
                              },
                              icon: const Icon(Icons.fit_screen_outlined),
                              label: const Text('Fit whole photo')),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Choose another')),
                      FilledButton.icon(
                          onPressed: () async {
                            final boundary = previewKey.currentContext
                                ?.findRenderObject() as RenderRepaintBoundary?;
                            if (boundary == null) return;
                            final image = await boundary.toImage(pixelRatio: 4);
                            final data = await image.toByteData(
                                format: ui.ImageByteFormat.png);
                            if (dialogContext.mounted && data != null) {
                              Navigator.pop(
                                  dialogContext, data.buffer.asUint8List());
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Use this photo'))
                    ])));
  }

  Future<void> _viewAvatar() => showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(alignment: Alignment.topRight, children: [
            InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Hero(
                    tag: 'my-marketplace-avatar',
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _avatarBytes != null
                            ? Image.memory(_avatarBytes!, fit: BoxFit.contain)
                            : Image.network(_photoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Material(
                                    child: Padding(
                                        padding: EdgeInsets.all(28),
                                        child: Text(
                                            'The profile photo could not be loaded.'))))))),
            IconButton.filled(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close))
          ])));

  Widget _completionCard() {
    if (!_profileSourceLoaded) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: Colors.deepOrange),
          SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Profile completion will appear when your saved profile finishes loading.',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final completion = _profileCompletion;
    final missing = _missingProfileItems;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Profile completion',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$completion%',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        LinearProgressIndicator(value: completion / 100, minHeight: 8),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Missing:',
                    style: TextStyle(fontSize: 11, color: Colors.red))),
            const SizedBox(width: 3),
            Expanded(
                child: Wrap(
                    spacing: 2,
                    runSpacing: 0,
                    children: missing
                        .map((item) => TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                minimumSize: const Size(0, 28),
                                textStyle: const TextStyle(fontSize: 11)),
                            onPressed: () => _goToMissing(item.$2),
                            child: Text(item.$1)))
                        .toList()))
          ])
        ],
      ]),
    );
  }

  List<(String, GlobalKey)> get _missingProfileItems {
    if (_accountType == 'business') {
      return [
        if (_businessName.text.trim().isEmpty)
          ('Business name', _businessNameKey),
        if (_legalBusinessName.text.trim().isEmpty)
          ('Legal name', _legalNameKey),
        if (_businessPhone.text.trim().isEmpty) ('Phone', _businessPhoneKey),
        if (_businessEmail.text.trim().isEmpty) ('Email', _businessEmailKey),
        if (_website.text.trim().isEmpty) ('Website', _websiteKey),
        if (_serviceAreaSelection == null) ('Service area', _serviceAreaKey),
        if (_businessAddress.text.trim().isEmpty)
          ('Address', _businessAddressKey),
        if (_businessBio.text.trim().isEmpty) ('Description', _businessBioKey),
      ];
    }
    return [
      if (_displayName.text.trim().isEmpty) ('Display name', _displayNameKey),
      if (_phone.text.trim().isEmpty) ('Phone', _phoneKey),
      if (_community.text.trim().isEmpty) ('Community', _communityKey),
      if (_personalBio.text.trim().isEmpty) ('About you', _personalBioKey),
    ];
  }

  Future<void> _goToMissing(GlobalKey key) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final target = key.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: .15);
    }
  }

  Widget _accountTypeBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Color(0xFFF0F5FA)),
        child: Row(children: [
          Icon(_accountType == 'business'
              ? Icons.verified_user_outlined
              : Icons.person_outline),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    _accountType == 'business'
                        ? 'Business account'
                        : 'Personal account',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_accountEmail.isEmpty ? 'Account email' : _accountEmail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF58697E))),
              ])),
          TextButton(
              onPressed: _saving
                  ? null
                  : () => _confirmAccountTypeChange(
                      _accountType == 'business' ? 'personal' : 'business'),
              child: const Text('Change')),
        ]),
      );

  Future<void> _confirmAccountTypeChange(String requested) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Change account type?'),
            content: Text(
                '${_accountEmail.isEmpty ? 'Your email' : _accountEmail} signed up under a ${_accountType == 'business' ? 'Business' : 'Personal'} account. Would you like to change to a ${requested == 'business' ? 'Business' : 'Personal'} account?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('No')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yes, change account')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await _repo.changeAccountType(requested);
      if (!mounted) return;
      setState(() => _accountType = requested);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Account changed to ${requested == 'business' ? 'Business' : 'Personal'}. Complete the active profile.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not change the account type.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _personalForm() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Form(
          key: _personalKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.onboarding)
              const _CompletionNotice(
                  text:
                      'Complete your contact details and seller information so you can list, buy, message and receive offers.'),
            const _PrivacyNotice(
                text:
                    'Your email, phone and legal identity remain private unless you choose to share them.'),
            _field(_displayName, 'Public display name',
                required: true,
                completionRequired: true,
                fieldKey: _displayNameKey),
            Padding(
                key: _phoneKey,
                padding: const EdgeInsets.only(bottom: 11),
                child: _missingBorder(
                    _phone.text.trim().isEmpty,
                    RegionalPhoneField(
                        label: 'Phone number',
                        initialValue: _phone.text,
                        onChanged: (value) {
                          _phone.text = value;
                          _profileFieldChanged();
                        }))),
            _field(_community, 'Base community',
                hint: 'Grande Prairie, Alberta',
                completionRequired: true,
                fieldKey: _communityKey),
            DropdownButtonFormField<String>(
              initialValue: _preferredContact,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Preferred contact'),
              items: const ['In-app message', 'Phone', 'Email', 'Text message']
                  .map((value) => DropdownMenuItem(
                      value: value,
                      child: MarketplaceFormOption(
                          label: value, icon: _preferredContactIcon(value))))
                  .toList(),
              onChanged: (value) => _preferredContact = value!,
            ),
            _field(_personalBio, 'About the seller',
                maxLines: 4,
                completionRequired: true,
                fieldKey: _personalBioKey),
            MarketplaceProfileTags(accountType: _accountType),
            _savedLocationsSection(),
            _saveButton('Save personal profile', _savePersonal),
          ]),
        ),
      );

  Widget _businessForm() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Form(
          key: _businessKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.onboarding)
              const _CompletionNotice(
                  text:
                      'Add your public business details and private legal address. You control what buyers can see.'),
            const _PrivacyNotice(
                text:
                    'Legal name, billing information and the private address are never shown on the public profile.'),
            _field(_businessName, 'Public business name',
                required: true,
                completionRequired: true,
                fieldKey: _businessNameKey),
            _field(_legalBusinessName, 'Legal business name (private)',
                completionRequired: true, fieldKey: _legalNameKey),
            Padding(
                key: _businessPhoneKey,
                padding: const EdgeInsets.only(bottom: 11),
                child: _missingBorder(
                    _businessPhone.text.trim().isEmpty,
                    RegionalPhoneField(
                        label: 'Public business phone',
                        initialValue: _businessPhone.text,
                        onChanged: (value) {
                          _businessPhone.text = value;
                          _profileFieldChanged();
                        }))),
            _field(_businessEmail, 'Public business email',
                keyboard: TextInputType.emailAddress,
                completionRequired: true,
                fieldKey: _businessEmailKey),
            _field(_website, 'Website',
                completionRequired: true, fieldKey: _websiteKey),
            Container(
              key: _serviceAreaKey,
              decoration: _missingDecoration(_serviceAreaSelection == null),
              child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await MarketplaceServiceAreaPicker.show(
                        context, _serviceAreaSelection);
                    if (selected == null || !mounted) return;
                    setState(() {
                      _serviceAreaSelection = selected;
                      _serviceArea.text = selected.summary;
                    });
                    _scheduleCompletionSync();
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(_serviceAreaSelection?.summary ??
                      'Select service area on map'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      alignment: Alignment.centerLeft)),
            ),
            const SizedBox(height: 11),
            OutlinedButton.icon(
                onPressed: () async {
                  final selected = await MarketplaceLocationPicker.show(
                      context, _businessYardLocation,
                      title: 'Business or yard location');
                  if (selected == null || !mounted) return;
                  setState(() {
                    _businessYardLocation = selected;
                    _businessAddress.text = selected.address;
                    if (_serviceArea.text.isEmpty) {
                      _serviceArea.text = selected.publicName;
                    }
                  });
                  _scheduleCompletionSync();
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(_businessYardLocation == null
                    ? 'Find business or yard and correct map pin'
                    : 'Yard pin: ${_businessYardLocation!.publicName}'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    alignment: Alignment.centerLeft)),
            const SizedBox(height: 11),
            Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: OpenAddressAutocomplete(
                    initialValue: _businessAddress.text,
                    label: 'Find business or yard address (private)',
                    onSelected: (address) {
                      _businessAddress.text = address.label;
                      if (_serviceArea.text.isEmpty) {
                        _serviceArea.text = [address.city, address.region]
                            .where((part) => part.isNotEmpty)
                            .join(', ');
                      }
                    })),
            _field(_businessAddress, 'Formatted private address',
                completionRequired: true, fieldKey: _businessAddressKey),
            _field(_businessBio,
                'Business description — what you sell, buy or service',
                hint:
                    'Example: Northern Alberta oilfield supplier specializing in used drill pipe, casing, hauling and yard pickup. Include equipment, industries, delivery area and what makes your business useful to buyers.',
                maxLines: 6,
                minLines: 4,
                maxLength: 800,
                completionRequired: true,
                fieldKey: _businessBioKey),
            MarketplaceProfileTags(accountType: _accountType),
            _savedLocationsSection(),
            _saveButton('Save business profile', _saveBusiness),
          ]),
        ),
      );

  Widget _field(TextEditingController controller, String label,
          {String? hint,
          bool required = false,
          bool completionRequired = false,
          GlobalKey? fieldKey,
          int maxLines = 1,
          int? minLines,
          int? maxLength,
          TextInputType? keyboard}) =>
      Padding(
        key: fieldKey,
        padding: const EdgeInsets.only(bottom: 11),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: keyboard,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: maxLength == null
                  ? null
                  : 'Describe your products, services, customers and coverage area.',
              enabledBorder:
                  completionRequired && controller.text.trim().isEmpty
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 1.5))
                      : null,
              labelStyle: completionRequired && controller.text.trim().isEmpty
                  ? const TextStyle(color: Colors.red)
                  : null),
          onChanged: (_) => _profileFieldChanged(),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
        ),
      );

  BoxDecoration? _missingDecoration(bool missing) => missing
      ? BoxDecoration(
          border: Border.all(color: Colors.red, width: 1.5),
          borderRadius: BorderRadius.circular(12))
      : null;

  Widget _missingBorder(bool missing, Widget child) => Container(
      decoration: _missingDecoration(missing),
      padding: missing ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: child);

  Widget _saveButton(String label, Future<void> Function() action) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: FilledButton(
            onPressed: _saving ? null : action,
            child: Text(_saving ? 'Saving…' : label)),
      );

  Widget _savedLocationsSection() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Saved yards, sites & locations',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            IconButton(
                tooltip: 'Add another location',
                onPressed: _addSavedLocation,
                icon: const Icon(Icons.add_location_alt_outlined)),
          ]),
          const Text(
              'Keep multiple business yards, remote sites, storage areas, pipe locations, personal sale areas, or places of interest.'),
          const SizedBox(height: 8),
          if (_savedLocations.isEmpty)
            OutlinedButton.icon(
                onPressed: _addSavedLocation,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add first saved location')),
          ..._savedLocations.map((data) {
            final location = MarketplaceLocation.fromPrivateData(data);
            final purpose = '${data['purpose'] ?? 'saved_location'}';
            return Card(
                child: ListTile(
              leading: Icon(_locationPurposeIcon(purpose)),
              title: Text(location.publicName),
              subtitle: Text('${_purposeLabel(purpose)} • Private exact pin'),
              onTap: () => _editSavedLocation(data, location),
              trailing: IconButton(
                  tooltip: 'Remove location',
                  onPressed: () => _removeSavedLocation('${data['id']}'),
                  icon: const Icon(Icons.delete_outline)),
            ));
          }),
        ]),
      );

  Future<void> _addSavedLocation() async {
    final purpose = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('What kind of location is this?'),
        children: [
          _purposeOption(
              dialogContext, 'business_yard', 'Business yard or shop'),
          _purposeOption(
              dialogContext, 'remote_site', 'Remote lease or work site'),
          _purposeOption(dialogContext, 'storage', 'Storage or pipe location'),
          _purposeOption(dialogContext, 'personal_sale_area',
              'Personal sale or pickup area'),
          _purposeOption(dialogContext, 'observed_interest',
              'Place where I saw something of interest'),
        ],
      ),
    );
    if (purpose == null || !mounted) return;
    final location = await MarketplaceLocationPicker.show(context, null,
        title: 'Add ${_purposeLabel(purpose)}');
    if (location == null || !mounted) return;
    await _repo.saveLocation(
        location: location.privateData(FirebaseAuth.instance.currentUser!.uid),
        purpose: purpose);
    await _reloadSavedLocations();
  }

  Widget _purposeOption(BuildContext context, String value, String label) =>
      SimpleDialogOption(
          onPressed: () => Navigator.pop(context, value), child: Text(label));

  Future<void> _editSavedLocation(
      Map<String, dynamic> data, MarketplaceLocation location) async {
    final updated = await MarketplaceLocationPicker.show(context, location,
        title: 'Move or edit saved location');
    if (updated == null || !mounted) return;
    await _repo.saveLocation(
        id: '${data['id']}',
        location: updated.privateData(FirebaseAuth.instance.currentUser!.uid),
        purpose: '${data['purpose'] ?? 'saved_location'}');
    await _reloadSavedLocations();
  }

  Future<void> _removeSavedLocation(String id) async {
    await _repo.deleteLocation(id);
    await _reloadSavedLocations();
  }

  Future<void> _reloadSavedLocations() async {
    final values = await _repo.loadSavedLocations();
    if (mounted) setState(() => _savedLocations = values);
  }

  String _purposeLabel(String purpose) => switch (purpose) {
        'business_yard' => 'Business yard',
        'remote_site' => 'Remote site',
        'storage' => 'Storage / pipe location',
        'personal_sale_area' => 'Personal sale area',
        'observed_interest' => 'Observed interest',
        _ => 'Saved location',
      };

  IconData _locationPurposeIcon(String purpose) => switch (purpose) {
        'business_yard' => Icons.warehouse_outlined,
        'remote_site' => Icons.oil_barrel_outlined,
        'storage' => Icons.inventory_2_outlined,
        'personal_sale_area' => Icons.home_work_outlined,
        'observed_interest' => Icons.visibility_outlined,
        _ => Icons.location_on_outlined,
      };

  Future<void> _savePersonal() async {
    if (!_personalKey.currentState!.validate()) return;
    await _save(() => _repo.savePersonal({
          'display_name': _displayName.text.trim(),
          'phone_number': _phone.text.trim(),
          'baseCommunity': _community.text.trim(),
          'sellerBio': _personalBio.text.trim(),
          'preferredContact': _preferredContact,
          'personalProfileComplete': true,
          'profileComplete': _accountType == 'personal',
          'profileCompletion': _profileCompletion,
        }));
  }

  Future<void> _saveBusiness() async {
    if (!_businessKey.currentState!.validate()) return;
    await _save(() => _repo.saveBusiness({
          'publicName': _businessName.text.trim(),
          'legalName': _legalBusinessName.text.trim(),
          'publicPhone': _businessPhone.text.trim(),
          'publicEmail': _businessEmail.text.trim(),
          'website': _website.text.trim(),
          'serviceArea': _serviceAreaSelection?.toMap(),
          'serviceAreaLabel': _serviceArea.text.trim(),
          'serviceCountryCodes':
              _serviceAreaSelection?.countryCodes ?? const <String>[],
          'serviceRegionKeys':
              _serviceAreaSelection?.regionKeys ?? const <String>[],
          'servicePlaceKeys':
              _serviceAreaSelection?.placeKeys ?? const <String>[],
          'privateAddress': _businessAddress.text.trim(),
          'yardLocation': _businessYardLocation
              ?.privateData(FirebaseAuth.instance.currentUser!.uid),
          'description': _businessBio.text.trim(),
          'businessProfileComplete': true,
          'profileCompletion': _profileCompletion,
        }));
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved.')));
        if (widget.onboarding) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          if (mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not save. Check Firebase rules and sign-in.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _profileFieldChanged() {
    setState(() {});
    _scheduleCompletionSync();
  }

  void _scheduleCompletionSync({bool immediate = false}) {
    _completionDebounce?.cancel();
    if (FirebaseAuth.instance.currentUser == null || !_profileSourceLoaded) {
      return;
    }
    if (immediate) {
      unawaited(
          _repo.updateProfileCompletion(_profileCompletion).catchError((_) {}));
      return;
    }
    _completionDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(
          _repo.updateProfileCompletion(_profileCompletion).catchError((_) {}));
    });
  }
}

class _CompletionNotice extends StatelessWidget {
  const _CompletionNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          border: Border.all(color: const Color(0xFFFF9A36)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.account_circle_outlined, color: Color(0xFFE56F00)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEAF4FD),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_user_outlined, color: Color(0xFF0878E8)),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ]),
      );
}
