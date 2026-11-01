import 'package:flutter/material.dart';

import '../l10n/account_strings.dart';
import '../models/evidence.dart';

/// Compact current metadata only: no history/network request for a marker.
class FeatureProvenance extends StatelessWidget {
  const FeatureProvenance({
    super.key,
    this.information = const {},
    this.compact = true,
  });
  final Map<String, dynamic> information;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final records = information['evidence'] is List
        ? (information['evidence'] as List).whereType<Map>().toList()
        : information['source'] != null
        ? <Map>[information]
        : <Map>[];
    final children = <Widget>[];
    if (information['state'] == 'divergent') {
      children.add(
        Text(
          accountText(
            context,
            'Há relatos diferentes sobre este recurso',
            'There are conflicting reports about this feature',
          ),
        ),
      );
    }
    if (records.isEmpty) {
      children.add(
        Text(
          accountText(
            context,
            information['evidence'] is List
                ? 'Sem fontes públicas para este recurso · Data desconhecida'
                : 'Origem não registrada · Data desconhecida',
            information['evidence'] is List
                ? 'No public sources for this feature · Date unknown'
                : 'Source not recorded · Date unknown',
          ),
        ),
      );
    }
    for (final record in records) {
      children.add(
        Text(
          '${evidenceSource(context, record['source_kind'] ?? record['source'])} · ${evidenceFreshness(context, record['freshness'])}',
        ),
      );
      if (!compact) {
        for (final pair in [
          ('observed_at', 'Observado em', 'Observed on'),
          ('received_at', 'Registrado em', 'Recorded on'),
          ('confirmed_at', 'Confirmado em', 'Confirmed on'),
          if (record['source'] == 'openstreetmap' ||
              record['source_kind'] == 'openstreetmap') ...[
            ('imported_at', 'Importado em', 'Imported on'),
            (
              'osm_modified_at',
              'Objeto OSM editado em',
              'OSM object edited on',
            ),
            ('snapshot_at', 'Snapshot do mapa', 'Map snapshot'),
          ],
        ]) {
          final date = evidenceDate(
            record[pair.$1] ??
                evidenceMap(record['reference'])[pair.$1] ??
                (pair.$1 == 'observed_at' ? record['observed_on'] : null),
          );
          children.add(
            Text(
              '${accountText(context, pair.$2, pair.$3)}: ${date == null ? accountText(context, 'não informado', 'not reported') : MaterialLocalizations.of(context).formatShortDate(date.toLocal())}',
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
