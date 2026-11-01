import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';

// Reject partial dates and DateTime's permissive calendar/time rollover.
DateTime? evidenceDate(Object? value) {
  if (value is! String) {
    return null;
  }
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?:[Zz]|[+-]\d{2}:?\d{2})?)?$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final calendar = DateTime.utc(y, m, d);
  if (calendar.year != y ||
      calendar.month != m ||
      calendar.day != d ||
      (int.tryParse(match[4] ?? '0') ?? 99) > 23 ||
      (int.tryParse(match[5] ?? '0') ?? 99) > 59 ||
      (int.tryParse(match[6] ?? '0') ?? 99) > 59) {
    return null;
  }
  return DateTime.tryParse(value);
}

Map<String, dynamic> evidenceMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
bool evidenceUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

String evidenceSource(BuildContext context, Object? source) => switch (source) {
  'user' || 'acessoja_community' => accountText(
    context,
    'Informado por usuário',
    'Reported by a user',
  ),
  'administrative' || 'acessoja_staff_update' || 'acessoja_registration' =>
    accountText(context, 'Cadastro administrativo', 'Administrative record'),
  'openstreetmap' => accountText(
    context,
    'Dados do OpenStreetMap',
    'OpenStreetMap data',
  ),
  _ => accountText(context, 'Origem não registrada', 'Source not recorded'),
};

String evidenceValue(BuildContext context, String state) => switch (state) {
  'presence_reported' => accountText(
    context,
    'Presença relatada',
    'Presence reported',
  ),
  'absence_reported' => accountText(
    context,
    'Ausência relatada',
    'Absence reported',
  ),
  'not_applicable' => accountText(
    context,
    'Informado como não aplicável',
    'Reported not applicable',
  ),
  'limited' => accountText(
    context,
    'Recurso com limitações relatadas',
    'Feature with reported limitations',
  ),
  'divergent' => accountText(
    context,
    'Há relatos diferentes sobre este recurso',
    'There are conflicting reports about this feature',
  ),
  _ => accountText(context, 'Informação desconhecida', 'Unknown information'),
};

String evidenceFreshness(BuildContext context, Object? raw) =>
    switch (evidenceMap(raw)['state']) {
      'recent_confirmation' => accountText(
        context,
        'Com confirmação recente',
        'Recently confirmed',
      ),
      'recent_observation' => accountText(
        context,
        'Observação recente informada, sem confirmação',
        'Recent observation reported, without confirmation',
      ),
      'recent_record' => accountText(
        context,
        'Registro recente, sem confirmação recente',
        'Recent record, without recent confirmation',
      ),
      'no_recent_confirmation' => accountText(
        context,
        'Sem confirmação recente',
        'No recent confirmation',
      ),
      _ => accountText(context, 'Data desconhecida', 'Date unknown'),
    };

class EvidenceFact {
  const EvidenceFact({
    required this.id,
    required this.resource,
    required this.revision,
    required this.state,
    this.source = 'not_recorded',
    this.note = '',
    this.observedAt,
    this.observedOn,
    this.receivedAt,
    this.confirmedAt,
    this.freshness = const {},
    this.reference = const {},
    this.canConfirm = false,
    this.canReport = false,
    this.canUpdate = false,
  });
  final String id, resource, revision, state, source, note;
  final DateTime? observedAt, observedOn, receivedAt, confirmedAt;
  final Map<String, dynamic> freshness, reference;
  final bool canConfirm, canReport, canUpdate;
  factory EvidenceFact.fromJson(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '',
        revision = data['revision']?.toString() ?? '';
    if (!evidenceUuid(id) ||
        !evidenceUuid(revision) ||
        data['resource'] is! String) {
      throw const FormatException('invalid_evidence');
    }
    return EvidenceFact(
      id: id,
      revision: revision,
      resource: data['resource'] as String,
      state: data['state']?.toString() ?? 'unknown',
      source: data['source']?.toString() ?? 'not_recorded',
      note: data['note']?.toString() ?? '',
      observedAt: evidenceDate(data['observed_at']),
      observedOn: evidenceDate(data['observed_on']),
      receivedAt: evidenceDate(data['received_at']),
      confirmedAt: evidenceDate(data['confirmed_at']),
      freshness: evidenceMap(data['freshness']),
      reference: evidenceMap(data['reference']),
      canConfirm: data['can_confirm'] == true,
      canReport: data['can_report'] == true,
      canUpdate: data['can_update'] == true,
    );
  }
}

class EvidencePage {
  const EvidencePage(this.items, this.next, [this.summary = const {}]);
  final List<EvidenceFact> items;
  final Map<String, dynamic> summary;
  final Uri? next;
}

class ReportTarget {
  const ReportTarget({
    required this.kind,
    required this.id,
    required this.revision,
    required this.description,
  });
  final String kind, id, revision, description;
  Map<String, dynamic> get body => {
    'target_kind': kind,
    'revision': revision,
    if (kind == 'review')
      'review_id': int.parse(id)
    else if (kind == 'photo')
      'photo_id': id
    else
      'evidence_id': id,
  };
}

class ReportReceipt {
  const ReportReceipt({
    required this.protocol,
    required this.state,
    this.reason = '',
    this.description = '',
    this.outcome = '',
    this.targetStatus = 'current',
    this.repeated = false,
    this.createdAt,
  });
  final String protocol, state, reason, description, outcome, targetStatus;
  final bool repeated;
  final DateTime? createdAt;
  factory ReportReceipt.fromJson(Map<String, dynamic> data) {
    final protocol = data['protocol']?.toString() ?? '';
    if (!evidenceUuid(protocol) ||
        ![
          'pending',
          'reviewing',
          'revision_requested',
          'closed',
        ].contains(data['state'])) {
      throw const FormatException('invalid_report_receipt');
    }
    return ReportReceipt(
      protocol: protocol,
      state: data['state'] as String,
      reason: data['reason']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      outcome: data['outcome']?.toString() ?? '',
      targetStatus: data['target_status']?.toString() ?? 'unavailable',
      repeated: data['repeated'] == true,
      createdAt: evidenceDate(data['created_at']),
    );
  }
}

String reportState(BuildContext context, String state) => switch (state) {
  'pending' => accountText(context, 'Pendente', 'Pending'),
  'reviewing' => accountText(context, 'Em análise', 'Under review'),
  'revision_requested' => accountText(
    context,
    'Aguardando revisão',
    'Revision requested',
  ),
  'closed' => accountText(context, 'Concluída', 'Closed'),
  _ => accountText(context, 'Estado indisponível', 'Status unavailable'),
};
