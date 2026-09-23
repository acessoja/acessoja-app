import 'package:flutter/material.dart';
import '../app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(
      {super.key,
      required this.title,
      required this.children,
      this.loading = false,
      this.error});
  final String title;
  final List<Widget> children;
  final bool loading;
  final Widget? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error ??
                    Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: children),
                        ))),
      );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection(
      {super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.text))),
            Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.border)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children)),
          ],
        ));
  }
}
