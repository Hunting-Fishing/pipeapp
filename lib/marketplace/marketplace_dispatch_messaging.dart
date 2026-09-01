import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_deep_links.dart';

Future<void> openDispatchContextConversation(
  BuildContext context, {
  required String jobId,
  String? bidId,
}) async {
  final normalizedJobId = jobId.trim();
  if (normalizedJobId.isEmpty) {
    PipeFeedback.show(
      context,
      message: 'This Dispatch job is unavailable.',
      tone: PipeStatusTone.error,
    );
    return;
  }
  try {
    final conversationId = await MarketplaceActionsRepository()
        .openDispatchConversation(jobId: normalizedJobId, bidId: bidId);
    if (!context.mounted) return;
    context.push(MarketplaceDeepLinks.conversation(conversationId));
  } catch (_) {
    if (!context.mounted) return;
    PipeFeedback.show(
      context,
      message:
          'The Dispatch conversation could not be opened. Confirm the job or quote is still available and try again.',
      tone: PipeStatusTone.error,
    );
  }
}
