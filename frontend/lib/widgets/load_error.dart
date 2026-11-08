import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../app_theme.dart';
import 'app_feedback.dart';

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AppFeedback(
        kind: AppFeedbackKind.error,
        message: context.l10n.loadError,
        actionLabel: context.l10n.retry,
        onAction: onRetry,
      ),
    ),
  );
}
