import 'package:flutter/foundation.dart';

/// Confirmed server mutations only. Private data stays in session-scoped owners.
final reviewChanges = ValueNotifier<int>(0);
