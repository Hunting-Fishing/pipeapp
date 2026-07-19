import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  PhoneRegion('CA', 'Canada', '+1', '🇨🇦', nationalDigits: 10),
  PhoneRegion('US', 'United States', '+1', '🇺🇸', nationalDigits: 10),
  PhoneRegion('PH', 'Philippines', '+63', '🇵🇭', nationalDigits: 10),
  PhoneRegion('MX', 'Mexico', '+52', '🇲🇽', nationalDigits: 10),
  PhoneRegion('GB', 'United Kingdom', '+44', '🇬🇧'),
  PhoneRegion('AU', 'Australia', '+61', '🇦🇺', nationalDigits: 9),
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
        text: _formatNational(_nationalDigits(widget.initialValue), _region));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()-]'))
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: _region.code == 'PH' ? '917 123 4567' : '(780) 555-1234',
          prefixIconConstraints: const BoxConstraints(minWidth: 126),
          prefixIcon: DropdownButtonHideUnderline(
            child: DropdownButton<PhoneRegion>(
              value: _region,
              padding: const EdgeInsets.only(left: 12),
              items: phoneRegions
                  .map((region) => DropdownMenuItem(
                      value: region,
                      child: Text('${region.flag} ${region.dialCode}')))
                  .toList(),
              onChanged: (region) {
                if (region == null) return;
                setState(() {
                  _region = region;
                  _controller.text =
                      _formatNational(_digits(_controller.text), region);
                });
                _emit();
              },
            ),
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
                selection: TextSelection.collapsed(offset: formatted.length));
          }
          _emit();
        },
      );

  void _emit() => widget.onChanged(_digits(_controller.text).isEmpty
      ? ''
      : '${_region.dialCode}${_digits(_controller.text)}');

  static PhoneRegion _regionFor(String value) {
    if (value.startsWith('+63')) return phoneRegions[2];
    if (value.startsWith('+52')) return phoneRegions[3];
    if (value.startsWith('+44')) return phoneRegions[4];
    if (value.startsWith('+61')) return phoneRegions[5];
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
