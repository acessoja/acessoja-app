import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/strings.dart';
import '../data/rights_catalog.dart';

export '../data/rights_catalog.dart' show RightsCategory;

const rightsLawUrl =
    'https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2015/lei/l13146.htm';
const rightsHelpUrl =
    'https://www.gov.br/pt-br/servicos/denunciar-violacao-de-direitos-humanos';
const rightsMoreUrl =
    'https://www.gov.br/mdh/pt-br/navegue-por-temas/pessoa-com-deficiencia/publicacoes/legislacao';

class RightsScreen extends StatefulWidget {
  const RightsScreen({super.key, this.openLink, this.category});

  final RightsCategory? category;

  /// Allows link behavior to be tested without opening a real browser.
  final Future<bool> Function(Uri)? openLink;

  /// Keep every entry point on the same route construction and history policy.
  static MaterialPageRoute<void> route({
    RightsCategory? category,
    Future<bool> Function(Uri)? openLink,
  }) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(
            name: category == null ? '/rights' : '/rights/${category.name}'),
        builder: (_) => RightsScreen(category: category, openLink: openLink),
      );

  @override
  State<RightsScreen> createState() => _RightsScreenState();
}

class _RightsScreenState extends State<RightsScreen> {
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (widget.category != null) {
      navigator.pushReplacement(RightsScreen.route(openLink: widget.openLink));
    } else {
      navigator.pushReplacementNamed('/');
    }
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      final opened = await (widget.openLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened) return;
    } catch (_) {
      // Keep the source available even when there is no browser handler.
    }
    if (!mounted) return;
    final strings = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.rightsLinkError),
        content: SingleChildScrollView(child: SelectableText(url)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.rightsCopied)),
              );
            },
            child: Text(strings.rightsCopyLink),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final colors = AppColors.of(context);
    final selected = widget.category;
    final entries =
        selected == null ? <RightsLaw>[] : rightsCatalog(s, selected);
    final topics = [
      s.rightsTransport,
      s.rightsPlaces,
      s.rightsHealth,
      s.rightsEducation,
      s.rightsWork,
      s.rightsCulture
    ];
    const icons = [
      Icons.directions_bus_outlined,
      Icons.storefront_outlined,
      Icons.health_and_safety_outlined,
      Icons.school_outlined,
      Icons.work_outline_rounded,
      Icons.theater_comedy_outlined
    ];

    Widget heading(String text) => Semantics(
          header: true,
          child: Text(text,
              style: TextStyle(
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: colors.text)),
        );
    Widget paragraph(String text) => Text(text,
        style: TextStyle(fontSize: 16, height: 1.5, color: colors.text));
    Widget sourceButton(String label, String url) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _open(url),
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.open_in_new_rounded, size: 20),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(label, style: const TextStyle(fontSize: 16))),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64 + MediaQuery.textScalerOf(context).scale(19) * 2,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              key: const ValueKey('rights-back'),
              onPressed: _goBack,
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              label: Text(s.back, style: const TextStyle(fontSize: 16)),
            ),
            Semantics(
                header: true,
                child: Text(
                  selected == null ? s.rightsTitle : topics[selected.index],
                  maxLines: 2,
                )),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              key: PageStorageKey('rights-scroll-${selected?.name ?? 'home'}'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: colors.primarySoft,
                          borderRadius: BorderRadius.circular(24)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.balance_rounded,
                                size: 36, color: colors.primary),
                            const SizedBox(height: 16),
                            heading(selected == null
                                ? s.rightsIntro
                                : s.rightsCategoryIntro),
                            const SizedBox(height: 12),
                            paragraph(selected == null
                                ? s.rightsDescription
                                : s.rightsCatalogNotice),
                            const SizedBox(height: 16),
                            Text(s.rightsScope,
                                style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ]),
                    ),
                    const SizedBox(height: 24),
                    if (selected == null) heading(s.rightsCategories),
                    const SizedBox(height: 12),
                    if (selected == null)
                      for (final category in RightsCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: colors.surface,
                            shape: RoundedRectangleBorder(
                                side: BorderSide(color: colors.border),
                                borderRadius: BorderRadius.circular(18)),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              key: ValueKey('category-${category.name}'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              leading: Icon(icons[category.index],
                                  color: colors.primary),
                              title: Text(topics[category.index],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(s.rightsBrowseCategory,
                                  style: TextStyle(color: colors.muted)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.push(
                                  context,
                                  RightsScreen.route(
                                      category: category,
                                      openLink: widget.openLink)),
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    for (final entry in entries)
                      Container(
                        key: ValueKey(entry.id),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(20)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icons[selected!.index],
                                  color: colors.primary, size: 30),
                              const SizedBox(height: 12),
                              heading(entry.title),
                              const SizedBox(height: 12),
                              paragraph(entry.summary),
                              const SizedBox(height: 16),
                              Text(entry.reference,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: colors.muted)),
                              sourceButton(s.rightsReadOfficial, entry.url),
                            ]),
                      ),
                    const SizedBox(height: 8),
                    sourceButton(s.rightsMoreLaws, rightsMoreUrl),
                    paragraph(s.rightsMoreDescription),
                    const SizedBox(height: 24),
                    heading(s.rightsHelpTitle),
                    const SizedBox(height: 12),
                    paragraph(s.rightsHelpBody),
                    sourceButton(s.rightsHelpLink, rightsHelpUrl),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider()),
                    Text(s.rightsReviewed,
                        style: TextStyle(
                            color: colors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(s.rightsNotice,
                        style: TextStyle(
                            color: colors.muted, fontSize: 14, height: 1.5)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
