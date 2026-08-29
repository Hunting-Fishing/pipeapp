import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class DispatchPromotionCodeField extends StatelessWidget {
  const DispatchPromotionCodeField({
    super.key,
    required this.controller,
    required this.onApply,
    required this.onChanged,
    this.enabled = true,
    this.busy = false,
    this.appliedSummary = '',
    this.helperText =
        'Enter a promo code here, or leave it blank and enter one on Stripe checkout.',
    this.applyLabel = 'Apply',
  });

  final TextEditingController controller;
  final VoidCallback onApply;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool busy;
  final String appliedSummary;
  final String helperText;
  final String applyLabel;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      enabled: enabled && !busy,
      textCapitalization: TextCapitalization.characters,
      autofillHints: const [AutofillHints.promoCode],
      maxLength: 64,
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Promo code (optional)',
        hintText: 'Enter promo code',
        prefixIcon: Icon(Icons.local_offer_outlined),
        border: OutlineInputBorder(),
        counterText: '',
      ),
      onSubmitted: (_) {
        if (enabled && !busy && controller.text.trim().isNotEmpty) onApply();
      },
    );

    final button = FilledButton.tonalIcon(
      onPressed: enabled && !busy ? onApply : null,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline_rounded),
      label: Text(busy ? 'Checking…' : applyLabel),
    );

    return Semantics(
      container: true,
      label: 'Dispatch promotion code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 460) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 10),
                    SizedBox(height: 56, child: button),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field,
                  const SizedBox(height: 8),
                  button,
                ],
              );
            },
          ),
          if (appliedSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: PipeBuyerColors.success,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    appliedSummary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PipeBuyerColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
