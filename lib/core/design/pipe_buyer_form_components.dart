import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

class PipeBuyerFormStepData {
  const PipeBuyerFormStepData({
    required this.label,
    required this.icon,
    this.optional = false,
  });

  final String label;
  final IconData icon;
  final bool optional;
}

class PipeBuyerGuidedFormShell extends StatelessWidget {
  const PipeBuyerGuidedFormShell({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.aside,
    this.footer,
  }) : assert(currentStep >= 0);

  final List<PipeBuyerFormStepData> steps;
  final int currentStep;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? aside;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.45,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PipeBuyerFormProgress(
              steps: steps,
              currentStep: currentStep,
            ),
            const SizedBox(height: 18),
            child,
            if (footer != null) ...[
              const SizedBox(height: 18),
              footer!,
            ],
          ],
        );

        if (!wide || aside == null) return body;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: body),
            const SizedBox(width: 20),
            SizedBox(width: 330, child: aside!),
          ],
        );
      },
    );
  }
}

class PipeBuyerFormProgress extends StatelessWidget {
  const PipeBuyerFormProgress({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  final List<PipeBuyerFormStepData> steps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          final index = currentStep.clamp(0, steps.length - 1).toInt();
          final step = steps[index];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _StepCircle(
                    index: index,
                    icon: step.icon,
                    state: _StepState.current,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${index + 1} of ${steps.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: PipeBuyerColors.orangePressed,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(((index + 1) / steps.length) * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          );
        }

        return Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                child: _StepNode(
                  data: steps[index],
                  index: index,
                  state: index < currentStep
                      ? _StepState.complete
                      : index == currentStep
                          ? _StepState.current
                          : _StepState.upcoming,
                ),
              ),
              if (index != steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: index < currentStep
                      ? PipeBuyerColors.orange
                      : Theme.of(context).colorScheme.outline,
                ),
            ],
          ],
        );
      },
    );
  }
}

enum _StepState { complete, current, upcoming }

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.data,
    required this.index,
    required this.state,
  });

  final PipeBuyerFormStepData data;
  final int index;
  final _StepState state;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepCircle(index: index, icon: data.icon, state: state),
          const SizedBox(height: 7),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: state == _StepState.current
                      ? FontWeight.w900
                      : FontWeight.w700,
                  color: state == _StepState.upcoming
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .52)
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
          if (data.optional)
            Text(
              'Optional',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .46),
                  ),
            ),
        ],
      );
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.index,
    required this.icon,
    required this.state,
  });

  final int index;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final active = state != _StepState.upcoming;
    final complete = state == _StepState.complete;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? PipeBuyerColors.orange : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: active ? PipeBuyerColors.orange : Theme.of(context).colorScheme.outline,
          width: state == _StepState.current ? 2 : 1,
        ),
      ),
      child: Icon(
        complete ? Icons.check_rounded : icon,
        size: 19,
        color: active
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
      ),
    );
  }
}

class PipeBuyerFormSection extends StatelessWidget {
  const PipeBuyerFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: PipeBuyerColors.orangePressed),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: .60),
                            height: 1.32,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class PipeBuyerFormTipCard extends StatelessWidget {
  const PipeBuyerFormTipCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lightbulb_outline_rounded,
    this.tone = PipeBuyerColors.industrialBlue,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: .22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: tone, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class PipeBuyerFormActionBar extends StatelessWidget {
  const PipeBuyerFormActionBar({
    super.key,
    this.onBack,
    this.onSaveDraft,
    this.onContinue,
    this.continueLabel = 'Continue',
    this.backLabel = 'Back',
    this.saveDraftLabel = 'Save Draft',
    this.busy = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onContinue;
  final String continueLabel;
  final String backLabel;
  final String saveDraftLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final back = OutlinedButton.icon(
                onPressed: busy ? null : onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(backLabel),
              );
              final draft = TextButton.icon(
                onPressed: busy ? null : onSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: Text(saveDraftLabel),
              );
              final next = FilledButton.icon(
                onPressed: busy ? null : onContinue,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(continueLabel),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    next,
                    if (onSaveDraft != null) ...[
                      const SizedBox(height: 6),
                      draft,
                    ],
                    if (onBack != null) ...[
                      const SizedBox(height: 6),
                      back,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  if (onBack != null) back,
                  if (onSaveDraft != null) ...[
                    const SizedBox(width: 8),
                    draft,
                  ],
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 150),
                    child: next,
                  ),
                ],
              );
            },
          ),
        ),
      );
}
