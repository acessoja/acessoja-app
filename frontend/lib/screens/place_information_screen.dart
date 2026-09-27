import 'accessibility_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../app_theme.dart';

Map<String, dynamic> visitMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Map<String, String> visitResourceLabels(BuildContext context) => {
      'rampa_acesso': context.l10n.visitRamp,
      'elevador': context.l10n.visitLift,
      'banheiro_acessivel': context.l10n.visitToilet,
      'vaga_reservada': context.l10n.visitParking,
      'circulacao': context.l10n.visitCirculation,
      'mesa_acessivel': context.l10n.visitTable,
      'cardapio_braille': context.l10n.visitMenu,
      'sinalizacao_tatil': context.l10n.visitTactile,
      'atendimento_acessivel': context.l10n.visitService,
      'cao_guia': context.l10n.visitGuideDog,
    };

/// Old false flags were defaults, not evidence of an inspected missing resource.
Map<String, dynamic> visitResources(Map<String, dynamic> place) {
  final resources = visitMap(visitMap(place['guia_visita'])['recursos']);
  for (final key in [
    'rampa_acesso',
    'banheiro_acessivel',
    'mesa_acessivel',
    'cardapio_braille',
    'cao_guia'
  ]) {
    if (!resources.containsKey(key) && place[key] == true) {
      resources[key] = {'estado': 'disponivel'};
    }
  }
  return resources;
}

String visitStatus(BuildContext context, dynamic value) => switch (value) {
      'disponivel' => context.l10n.visitAvailable,
      'indisponivel' => context.l10n.visitUnavailable,
      'nao_se_aplica' => context.l10n.visitNotApplicable,
      _ => context.l10n.visitUnknown,
    };

class VisitAccessibilitySummary extends StatelessWidget {
  const VisitAccessibilitySummary({super.key, required this.place});
  final Map<String, dynamic> place;

  @override
  Widget build(BuildContext context) {
    final resources = visitResources(place);
    final labels = visitResourceLabels(context);
    return Card(
      elevation: 0,
      color: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.of(context).border),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.l10n.visitAccessibility,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final key in ['rampa_acesso', 'banheiro_acessivel'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  '${labels[key]}: ${visitStatus(context, visitMap(resources[key])['estado'])}'),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(PlaceInformationScreen.route(place)),
            icon: const Icon(Icons.info_outline),
            label: Text(context.l10n.visitFullDetails),
          ),
        ]),
      ),
    );
  }
}

class PlaceInformationScreen extends StatelessWidget {
  const PlaceInformationScreen(
      {super.key, required this.place, this.area, this.openLink});
  final Map<String, dynamic> place;
  final Map<String, dynamic>? area;
  final Future<bool> Function(Uri)? openLink;

  static MaterialPageRoute<void> route(Map<String, dynamic> place,
          {Map<String, dynamic>? area, int? areaIndex}) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(
            name:
                '/places/${place['id_local']}/information${area == null ? '' : '/areas/$areaIndex'}'),
        builder: (_) => PlaceInformationScreen(place: place, area: area),
      );

  Future<void> _open(BuildContext context, String value,
      {bool phone = false}) async {
    final uri = phone
        ? Uri(scheme: 'tel', path: value.replaceAll(RegExp(r'[^0-9+]'), ''))
        : Uri.tryParse(value);
    try {
      if (uri != null &&
          (phone ||
              (['https', 'http'].contains(uri.scheme) &&
                  uri.host.isNotEmpty))) {
        if (await (openLink?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication))) {
          return;
        }
      }
    } catch (_) {
      // Retain selectable contact information if a handler is unavailable.
    }
    if (!context.mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.visitLinkError),
              content: SelectableText(value),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.back))
              ],
            ));
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        elevation: 0,
        color: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.of(context).border),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...children
              ],
            )),
      );

  String _text(BuildContext context, dynamic value) =>
      value is String && value.trim().isNotEmpty
          ? value
          : context.l10n.visitUnknown;

  Widget _provenance(BuildContext context, Map<String, dynamic> data) {
    final date = DateTime.tryParse('${data['atualizado_em'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
          '${context.l10n.visitSource}: ${_text(context, data['fonte'])}\n'
          '${context.l10n.visitUpdated}: ${date == null ? context.l10n.visitUnknown : DateFormat.yMd(Localizations.localeOf(context).toString()).format(date)}',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = area ?? visitMap(place['guia_visita']);
    final resources =
        area == null ? visitResources(place) : visitMap(data['recursos']);
    final rawAreas = data['areas'];
    final areas = rawAreas is List
        ? rawAreas.whereType<Map>().map(visitMap).toList()
        : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(
        actions: const [AccessibilitySettingsButton()],
        leadingWidth: 112,
        leading: TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text(context.l10n.back)),
        title: Text(context.l10n.visitGuide),
      ),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          key: PageStorageKey(
              'visit-${place['id_local']}-${area?['nome'] ?? 'main'}'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('${data['nome'] ?? place['nome'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall),
            if (area == null && (place['endereco'] ?? '').toString().isNotEmpty)
              Text(place['endereco'].toString()),
            const SizedBox(height: 16),
            _section(context, context.l10n.visitAbout, [
              if (data['categoria'] != null)
                Text('${context.l10n.placeCategoryField}: ${{
                      'educacao': context.l10n.categoryEducation,
                      'alimentacao': context.l10n.categoryFood,
                      'saude': context.l10n.categoryHealth,
                      'comercio': context.l10n.categoryCommerce,
                      'servico': context.l10n.categoryService,
                      'lazer': context.l10n.categoryLeisure,
                      'outro': context.l10n.categoryOther,
                    }[data['categoria']] ?? context.l10n.categoryOther}'),
              Text(_text(context, data['descricao'])),
              _provenance(context, data),
            ]),
            if (area == null)
              _section(context, context.l10n.visitHours, [
                Text(_text(context, data['horarios'])),
                const SizedBox(height: 12),
                Text(
                    '${context.l10n.visitPhone}: ${_text(context, data['telefone'])}'),
                if ((data['telefone'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                      onPressed: () =>
                          _open(context, data['telefone'], phone: true),
                      icon: const Icon(Icons.phone_outlined),
                      label: Text(context.l10n.visitPhone)),
                if ((data['site'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                      onPressed: () => _open(context, data['site']),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(context.l10n.visitWebsite))
                else
                  Text(
                      '${context.l10n.visitWebsite}: ${context.l10n.visitUnknown}'),
              ]),
            _section(context, context.l10n.visitEntrance, [
              Text(_text(context, data['entrada'])),
              if (Uri.tryParse('${data['foto'] ?? ''}')?.scheme == 'https') ...[
                const SizedBox(height: 12),
                Image.network(data['foto'],
                    height: 220,
                    fit: BoxFit.cover,
                    semanticLabel: context.l10n.visitEntrance,
                    errorBuilder: (_, error, stack) =>
                        const Icon(Icons.image_not_supported_outlined)),
              ],
            ]),
            _section(context, context.l10n.visitAccessibility, [
              Text(context.l10n.visitConfirm),
              const SizedBox(height: 12),
              for (final entry in visitResourceLabels(context).entries)
                ExpansionTile(
                  key: PageStorageKey('resource-${entry.key}'),
                  tilePadding: EdgeInsets.zero,
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  title: Text(entry.value),
                  subtitle: Text(visitStatus(
                      context, visitMap(resources[entry.key])['estado'])),
                  children: [
                    if ((visitMap(resources[entry.key])['observacao'] ?? '')
                        .toString()
                        .isNotEmpty)
                      Text(visitMap(resources[entry.key])['observacao']),
                    _provenance(context, visitMap(resources[entry.key])),
                    const SizedBox(height: 12),
                  ],
                ),
            ]),
            if (area == null && areas.isNotEmpty)
              _section(context, context.l10n.visitAreas, [
                Text(context.l10n.visitAreasHint),
                for (var index = 0; index < areas.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_text(context, areas[index]['nome'])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        route(place, area: areas[index], areaIndex: index)),
                  ),
              ]),
          ],
        ),
      ))),
    );
  }
}
