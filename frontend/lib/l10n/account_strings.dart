import 'package:flutter/material.dart';

String accountText(BuildContext context, String pt, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : pt;
