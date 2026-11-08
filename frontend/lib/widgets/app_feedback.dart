import 'package:flutter/material.dart';

import '../app_theme.dart';

enum AppFeedbackKind { information, loading, success, error }

/// A translated message with an icon and a live region, never color alone.
/// The caller owns the operation and supplies the existing localized text.
class AppFeedback extends StatelessWidget {
  const AppFeedback({
    super.key,
    required this.message,
    this.kind = AppFeedbackKind.information,
    this.actionLabel,
    this.onAction,
    this.liveRegion = true,
  });

  final String message;
  final AppFeedbackKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (foreground, background, icon) = switch (kind) {
      AppFeedbackKind.error => (
        colors.danger,
        colors.dangerSoft,
        Icons.error_outline,
      ),
      AppFeedbackKind.success => (
        colors.success,
        colors.successSoft,
        Icons.check_circle_outline,
      ),
      _ => (colors.primaryDark, colors.primarySoft, Icons.info_outline),
    };
    return Semantics(
      liveRegion: liveRegion,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(background, colors.surface),
          borderRadius: BorderRadius.circular(AppGeometry.controlRadius),
          border: Border.all(color: foreground),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: kind == AppFeedbackKind.loading
                        ? SizedBox.square(
                            dimension: AppGeometry.iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: foreground,
                            ),
                          )
                        : Icon(icon, color: foreground),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
