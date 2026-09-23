import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'generated/app_localizations.dart';

extension AppStrings on BuildContext {
  String apiMessage(String? code, {required String fallback}) => switch (code) {
        'invalid_credentials' => l10n.invalidCredentials,
        'connection_error' => l10n.connectionError,
        'evaluation_error' => l10n.evaluationError,
        _ => code == null || code.isEmpty ? fallback : code,
      };
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('pt'));

  String number(num value, {int digits = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: Localizations.localeOf(this).languageCode,
        decimalDigits: digits,
      ).format(value);

  String surveyAnswer(String value) => switch (value) {
        'Sim' => l10n.yes,
        'Não' => l10n.no,
        _ => l10n.unknown,
      };
}
