import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

class AjudaScreen extends StatelessWidget {
  const AjudaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final List<Map<String, String>> faqItems = [
      {
        'q': context.l10n.findPlacesQuestion,
        'a': context.l10n.findPlacesAnswer,
      },
      {
        'q': context.l10n.reviewQuestion,
        'a': context.l10n.reviewAnswer,
      },
      {
        'q': context.l10n.routeQuestion,
        'a': context.l10n.routeAnswer,
      },
      {
        'q': context.l10n.photoQuestion,
        'a': context.l10n.photoAnswer,
      },
      {
        'q': context.l10n.privacyQuestion,
        'a': context.l10n.privacyAnswer,
      },
      {
        'q': context.l10n.suggestionsQuestion,
        'a': context.l10n.suggestionsAnswer,
      },
    ];

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
          child: _buildBackButton(context),
        ),
        title: Text(
          context.l10n.help,
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        label: context.l10n.helpCenter,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  color: colors.onPrimary,
                                  size: 29,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.helpTitle,
                                      style: TextStyle(
                                        color: colors.primaryDark,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      context.l10n.helpIntro,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.faqTitle,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...faqItems.map(
                        (item) => _FaqTile(
                          question: item['q']!,
                          answer: item['a']!,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: colors.primarySoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: colors.primaryDark,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                  context.l10n.contact,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              context.l10n.contactIntro,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SelectableText(
                              'suporte@acessoja.com.br',
                              style: TextStyle(
                                color: colors.primaryDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'AcessoJá v1.0.0',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: context.l10n.back,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.primaryDark,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends SafeState<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded ? colors.primary : colors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: colors.primarySoft,
            highlightColor: colors.primarySoft,
          ),
          child: Semantics(
            label: widget.question,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 3,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                widget.question,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: colors.primaryDark,
                  size: 23,
                ),
              ),
              onExpansionChanged: (v) => setState(() => _expanded = v),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.answer,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
