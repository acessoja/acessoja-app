/// Feedback is populated only from a confirmed API response.
class ContributionMutation {
  final String operation;
  final String? outcome;
  final int? pointsDelta;
  const ContributionMutation({required this.operation, this.outcome, this.pointsDelta});

  factory ContributionMutation.fromResponse(Map<String, dynamic> response,
      {required String operation}) {
    final nested = response['contribution_result'];
    final result = nested is Map ? nested : response;
    final delta = result['points_delta'] ?? response['points_delta'];
    return ContributionMutation(
      operation: (result['operation'] ?? operation).toString(),
      outcome: result['outcome']?.toString(),
      pointsDelta: delta is num ? delta.toInt() : null,
    );
  }
}
