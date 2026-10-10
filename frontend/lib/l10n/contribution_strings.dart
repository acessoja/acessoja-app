import 'package:flutter/widgets.dart';

/// Uses the same locale selected by the application's preferences.
extension ContributionStrings on BuildContext {
  String contributionText(String pt, String en) =>
      Localizations.localeOf(this).languageCode == 'en' ? en : pt;
}
