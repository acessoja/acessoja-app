import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import 'app_feedback.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.loading = false,
    this.error,
    this.notice,
  });
  final String title;
  final List<Widget> children;
  final bool loading;
  final Widget? error;
  final Widget? notice;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: loading
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppFeedback(
                  kind: AppFeedbackKind.loading,
                  message: context.l10n.loadingSettings,
                ),
              ),
            )
          : error ??
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppGeometry.contentMaxWidth,
                    ),
                    child: notice == null
                        ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: children,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) => Column(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: constraints.maxHeight * .32,
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      8,
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: notice,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.all(20),
                                    children: children,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
    ),
  );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: AppTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppGeometry.panelRadius),
              side: BorderSide(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
