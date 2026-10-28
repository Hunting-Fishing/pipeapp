import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'pipebuyer_business_logo_uploader.dart';

enum PipeBuyerBadgeVariant {
  programPreview,
  featured,
  oilfieldBroker,
  specialtyMga,
  directCarrier,
  fastCoi24x7,
  msaReady,
  verifiedPro,
  verifiedBasic,
}

/// High-craft industrial status & classification badge with micro-icon,
/// subtle gradient fill, and crisp border hierarchy.
class PipeBuyerVisualBadge extends StatelessWidget {
  const PipeBuyerVisualBadge({
    super.key,
    required this.variant,
    this.label,
    this.compact = false,
    this.customIcon,
  });

  factory PipeBuyerVisualBadge.forInsuranceProviderType(
    String providerType, {
    bool compact = false,
  }) {
    final normalized = providerType.trim().toLowerCase();
    return switch (normalized) {
      'carrier' => PipeBuyerVisualBadge(
          variant: PipeBuyerBadgeVariant.directCarrier,
          compact: compact,
        ),
      'mga' => PipeBuyerVisualBadge(
          variant: PipeBuyerBadgeVariant.specialtyMga,
          compact: compact,
        ),
      _ => PipeBuyerVisualBadge(
          variant: PipeBuyerBadgeVariant.oilfieldBroker,
          compact: compact,
        ),
    };
  }

  final PipeBuyerBadgeVariant variant;
  final String? label;
  final bool compact;
  final IconData? customIcon;

  @override
  Widget build(BuildContext context) {
    final spec = _specForVariant(variant);
    final resolvedLabel = (label ?? spec.defaultLabel).trim();
    final iconSize = compact ? 11.5 : 13.0;
    final fontSize = compact ? 9.5 : 10.5;
    final hPad = compact ? 7.0 : 9.5;
    final vPad = compact ? 2.5 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.gradientColors,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: spec.borderColor,
          width: spec.prominentBorder ? 1.2 : 1.0,
        ),
        boxShadow: spec.glowColor == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: spec.glowColor!,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.showLiveDot) ...[
            Container(
              width: compact ? 5.5 : 6.5,
              height: compact ? 5.5 : 6.5,
              decoration: BoxDecoration(
                color: spec.iconColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: compact ? 3.5 : 4.5),
          ],
          Icon(
            customIcon ?? spec.icon,
            size: iconSize,
            color: spec.iconColor,
          ),
          SizedBox(width: compact ? 3.5 : 4.5),
          Flexible(
            child: Text(
              resolvedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.45,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeVisualSpec _specForVariant(PipeBuyerBadgeVariant variant) {
    return switch (variant) {
      PipeBuyerBadgeVariant.programPreview => const _BadgeVisualSpec(
          defaultLabel: 'PROGRAM PREVIEW',
          icon: Icons.auto_awesome_mosaic_outlined,
          gradientColors: <Color>[Color(0xFFEEF4FF), Color(0xFFDBEAFE)],
          borderColor: Color(0xFF93C5FD),
          iconColor: Color(0xFF1D4ED8),
          textColor: Color(0xFF1E3A8A),
        ),
      PipeBuyerBadgeVariant.featured => const _BadgeVisualSpec(
          defaultLabel: 'FEATURED',
          icon: Icons.workspace_premium_rounded,
          gradientColors: <Color>[Color(0xFFFF7A18), Color(0xFFD94E00)],
          borderColor: Color(0xFFFFB366),
          iconColor: Color(0xFFFFE599),
          textColor: Colors.white,
          prominentBorder: true,
          glowColor: Color(0x28FF6A00),
        ),
      PipeBuyerBadgeVariant.oilfieldBroker => const _BadgeVisualSpec(
          defaultLabel: 'OILFIELD BROKER',
          icon: Icons.handshake_outlined,
          gradientColors: <Color>[Color(0xFF0F294A), Color(0xFF19457A)],
          borderColor: Color(0xFF3B6EA8),
          iconColor: Color(0xFF93C5FD),
          textColor: Colors.white,
        ),
      PipeBuyerBadgeVariant.specialtyMga => const _BadgeVisualSpec(
          defaultLabel: 'SPECIALTY MGA',
          icon: Icons.policy_outlined,
          gradientColors: <Color>[Color(0xFF1E1B4B), Color(0xFF312E81)],
          borderColor: Color(0xFF6366F1),
          iconColor: Color(0xFFC7D2FE),
          textColor: Colors.white,
        ),
      PipeBuyerBadgeVariant.directCarrier => const _BadgeVisualSpec(
          defaultLabel: 'DIRECT CARRIER',
          icon: Icons.account_balance_outlined,
          gradientColors: <Color>[Color(0xFF0F172A), Color(0xFF1E293B)],
          borderColor: Color(0xFF475569),
          iconColor: Color(0xFFFBBF24),
          textColor: Colors.white,
        ),
      PipeBuyerBadgeVariant.fastCoi24x7 => const _BadgeVisualSpec(
          defaultLabel: '24/7 COI',
          icon: Icons.bolt_rounded,
          gradientColors: <Color>[Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          borderColor: Color(0xFF34D399),
          iconColor: Color(0xFF047857),
          textColor: Color(0xFF065F46),
          showLiveDot: true,
        ),
      PipeBuyerBadgeVariant.msaReady => const _BadgeVisualSpec(
          defaultLabel: 'MSA-READY',
          icon: Icons.verified_user_rounded,
          gradientColors: <Color>[Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
          borderColor: Color(0xFF5EEAD4),
          iconColor: Color(0xFF0F766E),
          textColor: Color(0xFF115E59),
        ),
      PipeBuyerBadgeVariant.verifiedPro => const _BadgeVisualSpec(
          defaultLabel: 'VERIFIED PRO',
          icon: Icons.verified_rounded,
          gradientColors: <Color>[Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          borderColor: Color(0xFF60A5FA),
          iconColor: PipeBuyerColors.industrialBlue,
          textColor: Color(0xFF1E3A8A),
        ),
      PipeBuyerBadgeVariant.verifiedBasic => const _BadgeVisualSpec(
          defaultLabel: 'VERIFIED',
          icon: Icons.check_circle_rounded,
          gradientColors: <Color>[Color(0xFFECFDF5), Color(0xFFDCFCE7)],
          borderColor: Color(0xFF4ADE80),
          iconColor: Color(0xFF16A34A),
          textColor: Color(0xFF15803D),
        ),
    };
  }
}

class _BadgeVisualSpec {
  const _BadgeVisualSpec({
    required this.defaultLabel,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    this.prominentBorder = false,
    this.showLiveDot = false,
    this.glowColor,
  });

  final String defaultLabel;
  final IconData icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final bool prominentBorder;
  final bool showLiveDot;
  final Color? glowColor;
}

/// Vector stacked-photo landscape thumbnail graphic rendered whenever a
/// business, insurance company, or partner brand has not provided an image.
class PipeBuyerImagePlaceholder extends StatelessWidget {
  const PipeBuyerImagePlaceholder({
    super.key,
    this.semanticsLabel = 'Business image placeholder',
  });

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: const SizedBox.expand(
        child: CustomPaint(
          painter: _StackedPhotoPlaceholderPainter(),
        ),
      ),
    );
  }
}

class _StackedPhotoPlaceholderPainter extends CustomPainter {
  const _StackedPhotoPlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final fullRect = Offset.zero & size;
    final backdropPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFD5D8DD), Color(0xFFC9CDD3)],
      ).createShader(fullRect);
    canvas.drawRect(fullRect, backdropPaint);

    final s = math.min(w, h);
    final cx = w / 2;
    final cy = h / 2;

    final whitePaint = Paint()
      ..color = const Color(0xFFF9FAFB)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final innerSlatePaint = Paint()
      ..color = const Color(0xFFC7CBD1)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final shadowPaint = Paint()
      ..color = const Color(0x180F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    // 1. Tilted back photo frame peeking behind the front frame
    canvas.save();
    canvas.translate(cx - s * 0.045, cy - s * 0.055);
    canvas.rotate(-0.225);
    final backW = s * 0.50;
    final backH = s * 0.36;
    final backOuter = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: backW, height: backH),
      Radius.circular(s * 0.036),
    );
    canvas.drawRRect(backOuter, whitePaint);

    final backInset = s * 0.048;
    final backInnerRect = Rect.fromCenter(
      center: Offset.zero,
      width: backW - backInset * 2,
      height: backH - backInset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(backInnerRect, Radius.circular(s * 0.014)),
      innerSlatePaint,
    );
    canvas.drawCircle(
      Offset(
        backInnerRect.right - backInnerRect.width * 0.25,
        backInnerRect.top + backInnerRect.height * 0.30,
      ),
      s * 0.040,
      whitePaint,
    );
    canvas.restore();

    // 2. Front horizontal photo frame with mountain & sun graphic
    final frontCenter = Offset(cx + s * 0.032, cy + s * 0.048);
    final frontW = s * 0.55;
    final frontH = s * 0.40;
    final frontRect = Rect.fromCenter(
      center: frontCenter,
      width: frontW,
      height: frontH,
    );
    final frontOuter = RRect.fromRectAndRadius(
      frontRect,
      Radius.circular(s * 0.038),
    );
    canvas.drawRRect(frontOuter.shift(Offset(0, s * 0.012)), shadowPaint);
    canvas.drawRRect(frontOuter, whitePaint);

    // Subtle crisp separator around front frame so stacked frames pop cleanly
    final separatorPaint = Paint()
      ..color = const Color(0xFFC5C9D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.012).clamp(0.6, 1.4);
    canvas.drawRRect(frontOuter, separatorPaint);

    final frontInset = s * 0.050;
    final inner = frontRect.deflate(frontInset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(s * 0.014)),
      innerSlatePaint,
    );

    // Sun circle in upper-right of inner canvas
    canvas.drawCircle(
      Offset(
        inner.right - inner.width * 0.21,
        inner.top + inner.height * 0.28,
      ),
      s * 0.044,
      whitePaint,
    );

    // Twin geometric mountain peaks with clean flat base margin
    final baseY = inner.bottom - inner.height * 0.11;
    final mountainPath = Path()
      ..moveTo(inner.left + inner.width * 0.06, baseY)
      ..lineTo(
        inner.left + inner.width * 0.26,
        inner.top + inner.height * 0.33,
      )
      ..lineTo(
        inner.left + inner.width * 0.45,
        inner.top + inner.height * 0.56,
      )
      ..lineTo(
        inner.left + inner.width * 0.54,
        inner.top + inner.height * 0.45,
      )
      ..lineTo(inner.right - inner.width * 0.07, baseY)
      ..close();
    canvas.drawPath(mountainPath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant _StackedPhotoPlaceholderPainter oldDelegate) =>
      false;
}

/// Framed corporate Business Logo container with clean aspect-preserving
/// rendering and neutral thumbnail placeholder image when no logo is provided.
class PipeBuyerCompanyLogoBadge extends StatelessWidget {
  const PipeBuyerCompanyLogoBadge({
    super.key,
    required this.logoUrl,
    required this.companyName,
    this.size = 48,
    this.width,
    this.height,
    this.featured = false,
    this.fallbackIcon,
  });

  final String logoUrl;
  final String companyName;
  final double size;
  final double? width;
  final double? height;
  final bool featured;
  final IconData? fallbackIcon;

  static String initialsFor(String rawName) {
    final words = rawName
        .trim()
        .split(RegExp(r'[\s&/,-]+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'PB';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  bool get _hasValidUrl {
    final trimmed = logoUrl.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('https://') ||
        trimmed.startsWith('http://127.0.0.1') ||
        trimmed.startsWith('http://localhost');
  }

  @override
  Widget build(BuildContext context) {
    final resolvedW = width ?? size;
    final resolvedH = height ?? size;
    final minDim = math.min(resolvedW, resolvedH);
    final radius = (minDim * 0.20).clamp(6.0, 13.0);
    final pad = minDim >= 44 ? 5.0 : 3.0;

    return Container(
      width: resolvedW,
      height: resolvedH,
      decoration: BoxDecoration(
        color: _hasValidUrl ? Colors.white : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _hasValidUrl && featured
              ? PipeBuyerColors.orange.withValues(alpha: 0.45)
              : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        boxShadow: minDim >= 40
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 1.0).clamp(4.0, 12.0)),
        child: _hasValidUrl
            ? ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Image.network(
                    logoUrl.trim(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildFallback(),
                  ),
                ),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    final trimmedName = companyName.trim();
    return PipeBuyerImagePlaceholder(
      semanticsLabel: trimmedName.isEmpty
          ? 'No business logo uploaded yet'
          : '$trimmedName placeholder image',
    );
  }
}

/// Interactive Business Logo upload & preview field used across Insurance
/// Provider onboarding, Business Directory listing forms, Partner With Us,
/// and Admin management dialogs.
class PipeBuyerBusinessLogoField extends StatefulWidget {
  const PipeBuyerBusinessLogoField({
    super.key,
    required this.logoUrl,
    required this.companyName,
    required this.purpose,
    required this.onChanged,
    this.uploader,
    this.title = 'Business Logo (Optional — Recommended)',
    this.subtitle =
        'Displayed on your company card & profile • PNG, JPG, or WebP (max 2 MB)',
    this.fieldKeyPrefix = 'business_logo',
  });

  final String logoUrl;
  final String companyName;
  final String purpose;
  final ValueChanged<String> onChanged;
  final PipeBuyerBusinessLogoUploader? uploader;
  final String title;
  final String subtitle;
  final String fieldKeyPrefix;

  @override
  State<PipeBuyerBusinessLogoField> createState() =>
      _PipeBuyerBusinessLogoFieldState();
}

class _PipeBuyerBusinessLogoFieldState
    extends State<PipeBuyerBusinessLogoField> {
  late PipeBuyerBusinessLogoUploader _uploader;
  late final TextEditingController _urlController;
  bool _uploading = false;
  bool _showUrlInput = false;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _uploader = widget.uploader ?? PipeBuyerBusinessLogoUploader();
    _urlController = TextEditingController(text: widget.logoUrl);
  }

  @override
  void didUpdateWidget(covariant PipeBuyerBusinessLogoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uploader != oldWidget.uploader) {
      _uploader = widget.uploader ?? PipeBuyerBusinessLogoUploader();
    }
    if (widget.logoUrl != oldWidget.logoUrl &&
        widget.logoUrl != _urlController.text.trim()) {
      _urlController.text = widget.logoUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _uploading = true;
      _urlError = null;
    });
    try {
      final uploadedUrl = await _uploader.pickAndUploadLogo(
        purpose: widget.purpose,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      if (uploadedUrl == null) return;
      _urlController.text = uploadedUrl;
      widget.onChanged(uploadedUrl);
      PipeFeedback.show(
        context,
        message: 'Business logo uploaded.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  void _applyTypedUrl(String raw) {
    final trimmed = raw.trim();
    final err = PipeBuyerBusinessLogoUploader.validateLogoUrl(trimmed);
    setState(() => _urlError = err);
    if (err == null) {
      widget.onChanged(trimmed);
    }
  }

  void _clearLogo() {
    _urlController.clear();
    setState(() => _urlError = null);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = widget.logoUrl.trim().isNotEmpty;
    final prefix = widget.fieldKeyPrefix;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PipeBuyerColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasLogo
              ? PipeBuyerColors.industrialBlue.withValues(alpha: 0.35)
              : PipeBuyerColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PipeBuyerCompanyLogoBadge(
                key: Key('${prefix}_preview'),
                logoUrl: widget.logoUrl,
                companyName: widget.companyName,
                width: 72,
                height: 60,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          key: Key('${prefix}_upload_button'),
                          onPressed: _uploading ? null : _pickAndUpload,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  hasLogo
                                      ? Icons.sync_rounded
                                      : Icons.upload_file_rounded,
                                  size: 17,
                                ),
                          label: Text(
                            _uploading
                                ? 'Uploading...'
                                : (hasLogo
                                    ? 'Replace Logo'
                                    : 'Upload Business Logo'),
                          ),
                        ),
                        TextButton.icon(
                          key: Key('${prefix}_url_toggle'),
                          onPressed: () {
                            setState(() => _showUrlInput = !_showUrlInput);
                          },
                          icon: const Icon(Icons.link_rounded, size: 17),
                          label: Text(
                            _showUrlInput ? 'Hide URL Field' : 'Paste Logo URL',
                          ),
                        ),
                        if (hasLogo)
                          TextButton.icon(
                            key: Key('${prefix}_remove_button'),
                            onPressed: _uploading ? null : _clearLogo,
                            style: TextButton.styleFrom(
                              foregroundColor: PipeBuyerColors.danger,
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showUrlInput) ...[
            const SizedBox(height: 12),
            TextField(
              key: Key('${prefix}_url_input'),
              controller: _urlController,
              keyboardType: TextInputType.url,
              onChanged: _applyTypedUrl,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Direct https:// Business Logo URL',
                hintText: 'https://yourcompany.com/assets/logo.png',
                errorText: _urlError,
                prefixIcon: const Icon(Icons.image_outlined, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
