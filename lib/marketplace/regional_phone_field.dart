import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/pipe_buyer_theme.dart';

class PhoneRegion {
  const PhoneRegion(this.code, this.name, this.dialCode, this.flag,
      {this.nationalDigits});
  final String code;
  final String name;
  final String dialCode;
  final String flag;
  final int? nationalDigits;
}

const phoneRegions = <PhoneRegion>[
  PhoneRegion('US', 'United States', '+1', '🇺🇸', nationalDigits: 10),
  PhoneRegion('CA', 'Canada', '+1', '🇨🇦', nationalDigits: 10),
  PhoneRegion('AF', 'Afghanistan', '+93', '🇦🇫'),
  PhoneRegion('AL', 'Albania', '+355', '🇦🇱'),
  PhoneRegion('DZ', 'Algeria', '+213', '🇩🇿'),
  PhoneRegion('AD', 'Andorra', '+376', '🇦🇩'),
  PhoneRegion('AO', 'Angola', '+244', '🇦🇴'),
  PhoneRegion('AR', 'Argentina', '+54', '🇦🇷'),
  PhoneRegion('AM', 'Armenia', '+374', '🇦🇲'),
  PhoneRegion('AU', 'Australia', '+61', '🇦🇺', nationalDigits: 9),
  PhoneRegion('AT', 'Austria', '+43', '🇦🇹'),
  PhoneRegion('AZ', 'Azerbaijan', '+994', '🇦🇿'),
  PhoneRegion('BS', 'Bahamas', '+1', '🇧🇸'),
  PhoneRegion('BH', 'Bahrain', '+973', '🇧🇭'),
  PhoneRegion('BD', 'Bangladesh', '+880', '🇧🇩'),
  PhoneRegion('BB', 'Barbados', '+1', '🇧🇧'),
  PhoneRegion('BY', 'Belarus', '+375', '🇧🇾'),
  PhoneRegion('BE', 'Belgium', '+32', '🇧🇪'),
  PhoneRegion('BZ', 'Belize', '+501', '🇧🇿'),
  PhoneRegion('BJ', 'Benin', '+229', '🇧🇯'),
  PhoneRegion('BO', 'Bolivia', '+591', '🇧🇴'),
  PhoneRegion('BA', 'Bosnia & Herzegovina', '+387', '🇧🇦'),
  PhoneRegion('BW', 'Botswana', '+267', '🇧🇼'),
  PhoneRegion('BR', 'Brazil', '+55', '🇧🇷'),
  PhoneRegion('BN', 'Brunei', '+673', '🇧🇳'),
  PhoneRegion('BG', 'Bulgaria', '+359', '🇧🇬'),
  PhoneRegion('BF', 'Burkina Faso', '+226', '🇧🇫'),
  PhoneRegion('KH', 'Cambodia', '+855', '🇰🇭'),
  PhoneRegion('CM', 'Cameroon', '+237', '🇨🇲'),
  PhoneRegion('CL', 'Chile', '+56', '🇨🇱'),
  PhoneRegion('CN', 'China', '+86', '🇨🇳'),
  PhoneRegion('CO', 'Colombia', '+57', '🇨🇴'),
  PhoneRegion('CR', 'Costa Rica', '+506', '🇨🇷'),
  PhoneRegion('HR', 'Croatia', '+385', '🇭🇷'),
  PhoneRegion('CU', 'Cuba', '+53', '🇨🇺'),
  PhoneRegion('CY', 'Cyprus', '+357', '🇨🇾'),
  PhoneRegion('CZ', 'Czech Republic', '+420', '🇨🇿'),
  PhoneRegion('DK', 'Denmark', '+45', '🇩🇰'),
  PhoneRegion('DO', 'Dominican Republic', '+1', '🇩🇴'),
  PhoneRegion('EC', 'Ecuador', '+593', '🇪🇨'),
  PhoneRegion('EG', 'Egypt', '+20', '🇪🇬'),
  PhoneRegion('SV', 'El Salvador', '+503', '🇸🇻'),
  PhoneRegion('EE', 'Estonia', '+372', '🇪🇪'),
  PhoneRegion('ET', 'Ethiopia', '+251', '🇪🇹'),
  PhoneRegion('FJ', 'Fiji', '+679', '🇫🇯'),
  PhoneRegion('FI', 'Finland', '+358', '🇫🇮'),
  PhoneRegion('FR', 'France', '+33', '🇫🇷'),
  PhoneRegion('GE', 'Georgia', '+995', '🇬🇪'),
  PhoneRegion('DE', 'Germany', '+49', '🇩🇪'),
  PhoneRegion('GH', 'Ghana', '+233', '🇬🇭'),
  PhoneRegion('GR', 'Greece', '+30', '🇬🇷'),
  PhoneRegion('GT', 'Guatemala', '+502', '🇬🇹'),
  PhoneRegion('HN', 'Honduras', '+504', '🇭🇳'),
  PhoneRegion('HK', 'Hong Kong', '+852', '🇭🇰'),
  PhoneRegion('HU', 'Hungary', '+36', '🇭🇺'),
  PhoneRegion('IS', 'Iceland', '+354', '🇮🇸'),
  PhoneRegion('IN', 'India', '+91', '🇮🇳'),
  PhoneRegion('ID', 'Indonesia', '+62', '🇮🇩'),
  PhoneRegion('IQ', 'Iraq', '+964', '🇮🇶'),
  PhoneRegion('IE', 'Ireland', '+353', '🇮🇪'),
  PhoneRegion('IL', 'Israel', '+972', '🇮🇱'),
  PhoneRegion('IT', 'Italy', '+39', '🇮🇹'),
  PhoneRegion('JM', 'Jamaica', '+1', '🇯🇲'),
  PhoneRegion('JP', 'Japan', '+81', '🇯🇵'),
  PhoneRegion('JO', 'Jordan', '+962', '🇯🇴'),
  PhoneRegion('KZ', 'Kazakhstan', '+7', '🇰🇿'),
  PhoneRegion('KE', 'Kenya', '+254', '🇰🇪'),
  PhoneRegion('KW', 'Kuwait', '+965', '🇰🇼'),
  PhoneRegion('LV', 'Latvia', '+371', '🇱🇻'),
  PhoneRegion('LB', 'Lebanon', '+961', '🇱🇧'),
  PhoneRegion('LT', 'Lithuania', '+370', '🇱🇹'),
  PhoneRegion('LU', 'Luxembourg', '+352', '🇱🇺'),
  PhoneRegion('MY', 'Malaysia', '+60', '🇲🇾'),
  PhoneRegion('MX', 'Mexico', '+52', '🇲🇽', nationalDigits: 10),
  PhoneRegion('MA', 'Morocco', '+212', '🇲🇦'),
  PhoneRegion('NL', 'Netherlands', '+31', '🇳🇱'),
  PhoneRegion('NZ', 'New Zealand', '+64', '🇳🇿'),
  PhoneRegion('NG', 'Nigeria', '+234', '🇳🇬'),
  PhoneRegion('NO', 'Norway', '+47', '🇳🇴'),
  PhoneRegion('OM', 'Oman', '+968', '🇴🇲'),
  PhoneRegion('PK', 'Pakistan', '+92', '🇵🇰'),
  PhoneRegion('PA', 'Panama', '+507', '🇵🇦'),
  PhoneRegion('PY', 'Paraguay', '+595', '🇵🇾'),
  PhoneRegion('PE', 'Peru', '+51', '🇵🇪'),
  PhoneRegion('PH', 'Philippines', '+63', '🇵🇭', nationalDigits: 10),
  PhoneRegion('PL', 'Poland', '+48', '🇵🇱'),
  PhoneRegion('PT', 'Portugal', '+351', '🇵🇹'),
  PhoneRegion('QA', 'Qatar', '+974', '🇶🇦'),
  PhoneRegion('RO', 'Romania', '+40', '🇷🇴'),
  PhoneRegion('SA', 'Saudi Arabia', '+966', '🇸🇦'),
  PhoneRegion('SG', 'Singapore', '+65', '🇸🇬'),
  PhoneRegion('ZA', 'South Africa', '+27', '🇿🇦'),
  PhoneRegion('KR', 'South Korea', '+82', '🇰🇷'),
  PhoneRegion('ES', 'Spain', '+34', '🇪🇸'),
  PhoneRegion('LK', 'Sri Lanka', '+94', '🇱🇰'),
  PhoneRegion('SE', 'Sweden', '+46', '🇸🇪'),
  PhoneRegion('CH', 'Switzerland', '+41', '🇨🇭'),
  PhoneRegion('TW', 'Taiwan', '+886', '🇹🇼'),
  PhoneRegion('TH', 'Thailand', '+66', '🇹🇭'),
  PhoneRegion('TT', 'Trinidad & Tobago', '+1', '🇹🇹'),
  PhoneRegion('TR', 'Turkey', '+90', '🇹🇷'),
  PhoneRegion('UA', 'Ukraine', '+380', '🇺🇦'),
  PhoneRegion('AE', 'United Arab Emirates', '+971', '🇦🇪'),
  PhoneRegion('GB', 'United Kingdom', '+44', '🇬🇧'),
  PhoneRegion('UY', 'Uruguay', '+598', '🇺🇾'),
  PhoneRegion('VE', 'Venezuela', '+58', '🇻🇪'),
  PhoneRegion('VN', 'Vietnam', '+84', '🇻🇳'),
];

String normalizePhoneNumber(String value) {
  if (value.trim().isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (value.trim().startsWith('+')) return '+$digits';
  return digits.length == 10 ? '+1$digits' : '+$digits';
}

String formatPhoneNumber(String value) {
  final normalized = normalizePhoneNumber(value);
  if (normalized.startsWith('+1') && normalized.length == 12) {
    final digits = normalized.substring(2);
    return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  if (normalized.startsWith('+63') && normalized.length == 13) {
    final digits = normalized.substring(3);
    return '+63 ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  return normalized;
}

class RegionalPhoneField extends StatefulWidget {
  const RegionalPhoneField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue = '',
    this.required = false,
  });

  final String label;
  final String initialValue;
  final bool required;
  final ValueChanged<String> onChanged;

  @override
  State<RegionalPhoneField> createState() => _RegionalPhoneFieldState();
}

class _RegionalPhoneFieldState extends State<RegionalPhoneField> {
  late PhoneRegion _region;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _region = _regionFor(widget.initialValue);
    _controller = TextEditingController(
      text: _formatNational(_nationalDigits(widget.initialValue), _region),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()-]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: _region.code == 'PH' ? '917 123 4567' : '(780) 555-1234',
        helperText:
            '${_region.flag} ${_region.name} • ${_region.dialCode} international format',
        helperMaxLines: 2,
        prefixIconConstraints: const BoxConstraints(minWidth: 128, maxWidth: 148),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: dark
                ? PipeBuyerColors.darkSurfaceMuted
                : PipeBuyerColors.surfaceMuted,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
            border: Border(
              right: BorderSide(
                color: dark ? PipeBuyerColors.darkLine : PipeBuyerColors.line,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PhoneRegion>(
              value: _region,
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              menuMaxHeight: 430,
              padding: const EdgeInsets.only(left: 12, right: 5),
              icon: const Icon(
                Icons.expand_more,
                size: 18,
                color: PipeBuyerColors.muted,
              ),
              selectedItemBuilder: (context) => phoneRegions
                  .map(
                    (region) => Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            region.flag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            region.dialCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              items: phoneRegions
                  .map(
                    (region) => DropdownMenuItem<PhoneRegion>(
                      value: region,
                      child: Row(
                        children: [
                          Text(region.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 9),
                          SizedBox(
                            width: 44,
                            child: Text(
                              region.dialCode,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              region.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (region) {
                if (region == null) return;
                setState(() {
                  _region = region;
                  _controller.text =
                      _formatNational(_digits(_controller.text), region);
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                });
                _emit();
              },
            ),
          ),
        ),
        suffixIcon: _controller.text.trim().isEmpty
            ? const Icon(Icons.phone_outlined)
            : Icon(
                _looksComplete(_controller.text, _region)
                    ? Icons.check_circle_outline
                    : Icons.phone_in_talk_outlined,
                color: _looksComplete(_controller.text, _region)
                    ? PipeBuyerColors.success
                    : PipeBuyerColors.muted,
              ),
      ),
      validator: (value) {
        final digits = _digits(value ?? '');
        if (digits.isEmpty) {
          return widget.required ? 'Phone number required' : null;
        }
        if (_region.nationalDigits case final length?) {
          if (digits.length != length) {
            return 'Enter a valid ${_region.name} number ($length digits)';
          }
        } else if (digits.length < 7 || digits.length > 12) {
          return 'Enter a valid phone number';
        }
        return null;
      },
      onChanged: (_) {
        final digits = _digits(_controller.text);
        final formatted = _formatNational(digits, _region);
        if (_controller.text != formatted) {
          _controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
        setState(() {});
        _emit();
      },
    );
  }

  void _emit() => widget.onChanged(
        _digits(_controller.text).isEmpty
            ? ''
            : '${_region.dialCode}${_digits(_controller.text)}',
      );

  static bool _looksComplete(String value, PhoneRegion region) {
    final digits = _digits(value);
    if (digits.isEmpty) return false;
    if (region.nationalDigits case final length?) {
      return digits.length == length;
    }
    return digits.length >= 7 && digits.length <= 12;
  }

  static PhoneRegion _regionFor(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return phoneRegions[0];
    for (final region in phoneRegions) {
      if (clean.startsWith(region.dialCode)) return region;
    }
    return phoneRegions[0];
  }

  static String _nationalDigits(String value) {
    final region = _regionFor(value);
    final all = _digits(value);
    final dial = _digits(region.dialCode);
    return value.startsWith('+') && all.startsWith(dial)
        ? all.substring(dial.length)
        : all;
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String _formatNational(String input, PhoneRegion region) {
    var digits = input;
    if (region.code == 'PH' && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (region.code == 'CA' || region.code == 'US') {
      digits = digits.substring(0, digits.length.clamp(0, 10));
      if (digits.length <= 3) return digits;
      if (digits.length <= 6) {
        return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
      }
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    if (region.code == 'PH') {
      digits = digits.substring(0, digits.length.clamp(0, 10));
      if (digits.length <= 3) return digits;
      if (digits.length <= 6) {
        return '${digits.substring(0, 3)} ${digits.substring(3)}';
      }
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    return RegExp(r'.{1,3}')
        .allMatches(digits)
        .map((m) => m.group(0))
        .join(' ');
  }
}
