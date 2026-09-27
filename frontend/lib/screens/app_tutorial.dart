import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

/// The invitation is remembered per account on this device, not on the server.
Future<void> inviteToTutorial(BuildContext context, String userName) async {
  final storage = await SharedPreferences.getInstance();
  final key = 'tutorial_invited_v1_$userName';
  if (storage.getBool(key) == true || !context.mounted) return;
  final t = context.l10n;
  final start = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(t.tutorialInvite),
            content: Text(t.tutorialInviteBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t.tutorialLater)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t.tutorialStart)),
            ],
          ));
  await storage.setBool(key, true);
  if (start == true && context.mounted) await showAppTutorial(context);
}

Future<void> showAppTutorial(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const AppTutorial());

class AppTutorial extends StatefulWidget {
  const AppTutorial({super.key});
  @override
  State<AppTutorial> createState() => _AppTutorialState();
}

class _AppTutorialState extends State<AppTutorial> {
  int _step = 0;
  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final steps = [
      (Icons.search, t.searchAddress, t.tutorialSearch),
      (Icons.explore_outlined, t.explore, t.tutorialExplore),
      (Icons.add_location_alt_outlined, t.addPlace, t.tutorialAdd),
      (Icons.balance_rounded, t.rightsTitle, t.tutorialRights),
      (Icons.accessibility_new_rounded, t.accessibility, t.tutorialAccess),
    ];
    final step = steps[_step];
    return AlertDialog(
      scrollable: true,
      title: Semantics(
          liveRegion: true,
          header: true,
          child: Text('${_step + 1}/${steps.length} · ${step.$2}')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(
            child: Icon(step.$1,
                size: 48, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 16),
        Text(step.$3),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.tutorialSkip)),
        if (_step > 0)
          TextButton(
              onPressed: () => setState(() => _step--), child: Text(t.back)),
        FilledButton(
            onPressed: () {
              if (_step == steps.length - 1) {
                Navigator.pop(context);
              } else {
                setState(() => _step++);
              }
            },
            child: Text(
                _step == steps.length - 1 ? t.tutorialFinish : t.tutorialNext)),
      ],
    );
  }
}
